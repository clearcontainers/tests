/// Copyight (c) 2017 Intel Corporation
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

package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"syscall"

	"github.com/BurntSushi/toml"
)

// Configuration stores all necessary
// information for checkmetrics execution
// and sent output as a report by email.
type Configuration struct {
	Mail MailConf
	Ck   Checkmetrics `toml:"checkmetrics"`
}

// MailConf stores the authentication
// configuration for sending the report
// by email. This information is parsed
// from TOML input file.
type MailConf struct {
	SMTP     string   // SMTP server address
	Port     string   // SMTP port
	User     string   // SMTP user
	Password string   // SMTP password
	ID       string   // SMTP indetity
	From     string   // Sender
	Subject  string   // Email msg subject
	To       []string // Receipts
	Cc       []string // Msg copy
}

// Checkmetrics stores the arguments
// for checkmetrics execution
type Checkmetrics struct {
	Cmd        string
	Basefile   string
	Metricsdir string
}

// System default path for configuration file
// the value will be set by Makefile
var sysConfFile string = ""

func main() {

	var confFile string
	var conf Configuration
	var comments string
	var body string
	var currentUID int
	var ownerUID int

	// Checkmetrics conf vars
	var cmd string
	var basefile string
	var metricsdir string

	flag.StringVar(&confFile, "f", "", "Configuration file")
	flag.StringVar(&comments, "c", "", "comments/suggestions")
	flag.Parse()

	// If there is not any input file specified by command line
	// it will look in default system path
	if confFile == "" {
		confFile = sysConfFile
	}

	// Get info about file
	fileinfo, err := os.Stat(confFile)
	if err != nil {
		log.Fatal(err)
	}

	// Owner verification
	currentUID = os.Geteuid()
	fStat := fileinfo.Sys().(*syscall.Stat_t)
	ownerUID = int(fStat.Uid)

	if currentUID != ownerUID {
		log.Fatal(currentUID,
			" is not the owner of ", confFile,
			" uid: ", ownerUID)
	}

	// Parsing TOML configuration file
	if _, err := toml.DecodeFile(confFile, &conf); err != nil {
		log.Fatal(err)
	}

	// Add comments to the body message
	if comments != "" {
		body = fmt.Sprintf(comments + "\n")
	}

	// Set checkmetrics configuration
	cmd = conf.Ck.Cmd
	basefile = conf.Ck.Basefile
	metricsdir = conf.Ck.Metricsdir

	// checkmetrics execution
	out, err := exec.Command(cmd, "--basefile", basefile, "--metricsdir", metricsdir).Output()
	if err != nil {
		body = fmt.Sprintf(body + "%s\n\n %v", out, err)
		SendByEmail(conf, body)
		log.Fatal("checkmetrics execution: ", err)
	}

	if len(out) == 0 {
		body = fmt.Sprintf(body + "no output from " + cmd)
		SendByEmail(conf, body)
		log.Fatal("no output from: " + cmd)
	}

	body = fmt.Sprintf(body + "%s", out)
	SendByEmail(conf, body)
}
