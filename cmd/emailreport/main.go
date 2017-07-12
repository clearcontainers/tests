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
	Smtp     string   // SMTP server address
	Port     string   // SMTP port
	User     string   // SMTP user
	Password string   // SMTP password
	Id       string   // SMTP indetity
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

func main() {

	var confFile string
	var conf Configuration
	var body string
	var currentUid int
	var ownerUid int

	// Checkmetrics conf vars
	var cmd string
	var basefile string
	var metricsdir string

	flag.StringVar(&confFile, "f", "", "Configuration file")
	flag.Parse()

	// Get info about file
	fileinfo, err := os.Stat(confFile)
	if err != nil {
		log.Fatal(err)
	}

	// Owner verification
	currentUid = os.Geteuid()
	fStat := fileinfo.Sys().(*syscall.Stat_t)
	ownerUid = int(fStat.Uid)

	if currentUid != ownerUid {
		log.Fatal(currentUid,
			" is not the owner of ", confFile,
			" uid: ", ownerUid)
	}

	// Parsing TOML configuration file
	if _, err := toml.DecodeFile(confFile, &conf); err != nil {
		log.Fatal(err)
	}

	// Set checkmetrics configuration
	cmd = conf.Ck.Cmd
	basefile = "--basefile " + conf.Ck.Basefile
	metricsdir = "--metricsdir " + conf.Ck.Metricsdir

	// checkmetrics execution
	out, err := exec.Command(cmd, basefile, metricsdir).Output()
	if err != nil {
		log.Fatal(err)
	}

	if len(out) == 0 {
		log.Fatal("no output from: " + cmd)
	}

	body = fmt.Sprintf("%s", out)
	SendByEmail(conf, body)
}
