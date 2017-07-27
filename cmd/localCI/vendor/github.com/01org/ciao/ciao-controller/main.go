/*
// Copyright (c) 2016 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
*/
// @APIVersion v2.1
// @APITitle CIAO Controller API
// @APIDescription Ciao controller is responsible for policy choices around tenant workloads. It provides compute API endpoints for access from ciao-cli and ciao-webui over HTTPS.
// @Contact https://github.com/01org/ciao/wiki/Package-maintainers
// @License Apache License, Version 2.0
// @LicenseUrl http://www.apache.org/licenses/LICENSE-2.0
// @BasePath http://<ciao-controller-server>:8774/v2.1/

package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"sync"

	"github.com/01org/ciao/ciao-controller/api"
	datastore "github.com/01org/ciao/ciao-controller/internal/datastore"
	image "github.com/01org/ciao/ciao-image/client"
	storage "github.com/01org/ciao/ciao-storage"
	"github.com/01org/ciao/clogger/gloginterface"
	"github.com/01org/ciao/database"
	"github.com/01org/ciao/openstack/block"
	"github.com/01org/ciao/openstack/compute"
	osIdentity "github.com/01org/ciao/openstack/identity"
	osimage "github.com/01org/ciao/openstack/image"
	"github.com/01org/ciao/osprepare"
	"github.com/01org/ciao/ssntp"
	"github.com/01org/ciao/testutil"
	"github.com/golang/glog"
	"github.com/gorilla/mux"
)

type tenantConfirmMemo struct {
	ch  chan struct{}
	err error
}

type controller struct {
	storage.BlockDriver

	client              controllerClient
	ds                  *datastore.Datastore
	id                  *identity
	image               image.Client
	apiURL              string
	tenantReadiness     map[string]*tenantConfirmMemo
	tenantReadinessLock sync.Mutex
}

var singleMachine = flag.Bool("single", false, "Enable single machine test")
var cert = flag.String("cert", "", "Client certificate")
var caCert = flag.String("cacert", "", "CA certificate")
var serverURL = flag.String("url", "", "Server URL")
var identityURL = "identity:35357"
var serviceUser = "csr"
var servicePassword = ""
var volumeAPIPort = block.APIPort
var computeAPIPort = compute.APIPort
var imageAPIPort = osimage.APIPort
var controllerAPIPort = api.Port
var httpsCAcert = "/etc/pki/ciao/ciao-controller-cacert.pem"
var httpsKey = "/etc/pki/ciao/ciao-controller-key.pem"
var tablesInitPath = flag.String("tables_init_path", "/var/lib/ciao/data/controller/tables", "path to csv files")
var workloadsPath = flag.String("workloads_path", "/var/lib/ciao/data/controller/workloads", "path to yaml files")
var noNetwork = flag.Bool("nonetwork", false, "Debug with no networking")
var persistentDatastoreLocation = flag.String("database_path", "/var/lib/ciao/data/controller/ciao-controller.db", "path to persistent database")
var imageDatastoreLocation = flag.String("image_database_path", "/var/lib/ciao/data/image/ciao-image.db", "path to image persistent database")
var transientDatastoreLocation = flag.String("stats_path", "/tmp/ciao-controller-stats.db", "path to stats database")
var logDir = "/var/lib/ciao/logs/controller"

var imagesPath = flag.String("images_path", "/var/lib/ciao/images", "path to ciao images")

var cephID = flag.String("ceph_id", "", "ceph client id")

func init() {
	flag.Parse()

	logDirFlag := flag.Lookup("log_dir")
	if logDirFlag == nil {
		glog.Errorf("log_dir does not exist")
		return
	}

	if logDirFlag.Value.String() == "" {
		logDirFlag.Value.Set(logDir)
	}

	if err := os.MkdirAll(logDirFlag.Value.String(), 0755); err != nil {
		glog.Errorf("Unable to create log directory (%s) %v", logDir, err)
		return
	}
}

func main() {
	var wg sync.WaitGroup
	var err error

	ctl := new(controller)
	ctl.tenantReadiness = make(map[string]*tenantConfirmMemo)
	ctl.ds = new(datastore.Datastore)

	ctl.image = image.Client{MountPoint: *imagesPath}

	dsConfig := datastore.Config{
		PersistentURI:     "file:" + *persistentDatastoreLocation,
		TransientURI:      "file:" + *transientDatastoreLocation,
		InitTablesPath:    *tablesInitPath,
		InitWorkloadsPath: *workloadsPath,
	}

	err = ctl.ds.Init(dsConfig)
	if err != nil {
		glog.Fatalf("unable to Init datastore: %s", err)
		return
	}

	config := &ssntp.Config{
		URI:    *serverURL,
		CAcert: *caCert,
		Cert:   *cert,
		Log:    ssntp.Log,
	}

	ctl.client, err = newSSNTPClient(ctl, config)
	if err != nil {
		// spawn some retry routine?
		glog.Fatalf("unable to connect to SSNTP server")
		return
	}

	ssntpClient := ctl.client.ssntpClient()
	clusterConfig, err := ssntpClient.ClusterConfiguration()
	if err != nil {
		glog.Fatalf("Unable to retrieve Cluster Configuration: %v", err)
		return
	}

	volumeAPIPort = clusterConfig.Configure.Controller.VolumePort
	computeAPIPort = clusterConfig.Configure.Controller.ComputePort
	controllerAPIPort = clusterConfig.Configure.Controller.CiaoPort
	httpsCAcert = clusterConfig.Configure.Controller.HTTPSCACert
	httpsKey = clusterConfig.Configure.Controller.HTTPSKey
	identityURL = clusterConfig.Configure.IdentityService.URL
	serviceUser = clusterConfig.Configure.Controller.IdentityUser
	servicePassword = clusterConfig.Configure.Controller.IdentityPassword
	if *cephID == "" {
		*cephID = clusterConfig.Configure.Storage.CephID
	}

	database.Logger = gloginterface.CiaoGlogLogger{}

	logger := gloginterface.CiaoGlogLogger{}
	osprepare.Bootstrap(context.TODO(), logger)
	osprepare.InstallDeps(context.TODO(), controllerDeps, logger)

	if *singleMachine {
		hostname, _ := os.Hostname()
		volumeURL := "https://" + hostname + ":" + strconv.Itoa(volumeAPIPort)
		imageURL := "https://" + hostname + ":" + strconv.Itoa(imageAPIPort)
		computeURL := "https://" + hostname + ":" + strconv.Itoa(computeAPIPort)
		testIdentityConfig := testutil.IdentityConfig{
			VolumeURL:  volumeURL,
			ImageURL:   imageURL,
			ComputeURL: computeURL,
			ProjectID:  "f452bbc7-5076-44d5-922c-3b9d2ce1503f",
		}

		id := testutil.StartIdentityServer(testIdentityConfig)
		defer id.Close()
		identityURL = id.URL
		glog.Errorf("========================")
		glog.Errorf("Identity URL: %s", id.URL)
		glog.Errorf("Please")
		glog.Errorf("export CIAO_IDENTITY=%s", id.URL)
		glog.Errorf("========================")
		glog.Flush()
	}

	idConfig := identityConfig{
		endpoint:        identityURL,
		serviceUserName: serviceUser,
		servicePassword: servicePassword,
	}

	ctl.BlockDriver = func() storage.BlockDriver {
		driver := storage.CephDriver{
			ID: *cephID,
		}
		return driver
	}()

	ctl.id, err = newIdentityClient(idConfig)
	if err != nil {
		glog.Fatal("Unable to authenticate to Keystone: ", err)
		return
	}

	wg.Add(1)
	go ctl.startComputeService()

	wg.Add(1)
	go ctl.startVolumeService()

	wg.Add(1)
	go ctl.startImageService()

	host, _ := os.Hostname()
	ctl.apiURL = fmt.Sprintf("https://%s:%d", host, controllerAPIPort)

	wg.Add(1)
	go ctl.startCiaoService()

	wg.Wait()
	ctl.ds.Exit()
	ctl.client.Disconnect()
}

func (c *controller) startCiaoService() error {
	config := api.Config{URL: c.apiURL, CiaoService: c}

	r := api.Routes(config)
	if r == nil {
		return errors.New("Unable to start Ciao API Service")
	}

	// wrap each route in keystone validation.
	validServices := []osIdentity.ValidService{
		{ServiceType: "compute", ServiceName: "ciao"},
		{ServiceType: "compute", ServiceName: "nova"},
	}

	validAdmins := []osIdentity.ValidAdmin{
		{Project: "service", Role: "admin"},
		{Project: "admin", Role: "admin"},
	}

	err := r.Walk(func(route *mux.Route, router *mux.Router, ancestors []*mux.Route) error {
		h := osIdentity.Handler{
			Client:        c.id.scV3,
			Next:          route.GetHandler(),
			ValidServices: validServices,
			ValidAdmins:   validAdmins,
		}

		route.Handler(h)

		return nil
	})

	if err != nil {
		return err
	}

	service := fmt.Sprintf(":%d", controllerAPIPort)

	glog.Infof("Starting ciao API on port %d\n", controllerAPIPort)

	err = http.ListenAndServeTLS(service, httpsCAcert, httpsKey, r)
	if err != nil {
		glog.Fatal(err)
	}

	return nil
}
