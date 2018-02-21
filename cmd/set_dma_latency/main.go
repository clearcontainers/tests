// Copyright (c) 2018 Intel Corporation
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
	"encoding/binary"
	"errors"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/urfave/cli"
)

// name is the name of the program.
const name = "set_dma_latency"

// usage is the usage of the program.
const usage = name +
` writes the single command line parameter to the /dev/cpu_dma_latency file, and holds the file open (to maintain the setting).
  It prints out its own PID on success.
  It never returns, and has to be killed.
  In order for this program to work you are likely to need to run this program with root privs.`



// path to the file we need to open and write to
const filepath = "/dev/cpu_dma_latency"

// how many us are we setting the latency to
var uslatency uint32

// set_dma_latency main entry point.
// check we have a valid parameter
// and then open the file and write the value
func main() {
	app := cli.NewApp()
	app.Name = name
	app.Usage = usage

	app.HideVersion = true

	cli.AppHelpTemplate = `NAME:
	{{.Name}} - {{.Usage}}
	USAGE:
	{{.HelpName}} {{if .VisibleFlags}}[global options]{{end}} latency_in_us
	{{if len .Authors}}
	AUTHOR:
	{{range .Authors}}{{ . }}{{end}}
	{{end}}{{if .Commands}}
	COMMANDS:
	{{range .Commands}}{{if not .HideHelp}}
	{{join .Names ", "}}{{ "\t"}}{{.Usage}}{{ "\n" }}{{end}}{{end}}{{end}}{{if .VisibleFlags}}
	GLOBAL OPTIONS:
	{{range .VisibleFlags}}{{.}}
	{{end}}{{end}}
	`

	app.Action = func(context *cli.Context) error {
		if context.NArg() != 1 {
			cli.ShowAppHelp(context)
			return errors.New("Wrong number of arguments")
		}

		u64, err := strconv.ParseUint(context.Args()[0], 0, 32)
		if err != nil {
			return err
		}

		uslatency = uint32(u64)

		file, err := os.OpenFile(filepath, os.O_WRONLY, 0600)
		if err != nil {
			return err
		}

		defer file.Close()

		buf := make([]byte, 4)
		// Normally we are writing '0', in which case the endian
		// does not matter. Other than that, the systems are normally
		// little endian, so let's go with that as the default.
		// If I could have seen a HostEndian option then I would have used
		// that.
		binary.LittleEndian.PutUint32(buf, uslatency)
		_, err = file.Write(buf)
		if err != nil {
			return err
		}

		fmt.Println(os.Getpid())

		// We must keep the file open to maintain the effect.
		// Sleep 'forever'.
		for true {
			time.Sleep(time.Second * 1000)
		}

		return nil
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
