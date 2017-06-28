// Copyright (c) 2017 Intel Corporation
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

/*
Program checkmetrics compares the results from a set of Clear Containers
metrics results, stored in CSV files, against a set of baseline metrics
'expectations', defined in a TOML file.

It returns non zero if any of the TOML metrics are not met.

it prints out a tabluated report summary at the end of the run.
*/
package main

import (
	"errors"
	"fmt"
	"os"
	"path"

	log "github.com/Sirupsen/logrus"
	"github.com/olekukonko/tablewriter"
	"github.com/urfave/cli"
)

// name is the name of the program.
const name = "checkmetrics"

// usage is the usage of the program.
const usage = name + ` checks CSV metrics results against a TOML baseline`

// The TOML basefile
var ciBasefile *baseFile

// processMetrics locates the CSV file matching each entry in the TOML
// baseline, loads and processes it, and checks if the metrics were in range.
// Finally it generates a summary report
func processMetrics(context *cli.Context) (err error) {
	var report [][]string // summary report table
	var passes int
	var fails int

	log.Debug("processMetrics")

	// Process each Metrics TOML entry one at a time
	for _, m := range ciBasefile.Metric {
		var thisCsv csvRecord

		log.Debugf("Processing %s", m.Name)
		fullpath := path.Join(context.GlobalString("metricsdir"), m.Name)
		fullpath = fullpath + ".csv"

		log.Debugf("Fullpath %s", fullpath)
		err = thisCsv.load(fullpath)
		if err != nil {
			log.Warnf("[%s][%v]", fullpath, err)
			// Record that this one did not complete successfully
			fails++
			// Make some sort of note in the summary table that this failed
			report = append(report,
				(&metricsCheck{}).genErrorLine(false, m.Name, "Failed to load CSV", fmt.Sprintf("%s", err)))
			// Not a fatal error - continue to process any remaining files
			continue
		}

		// Now we have both the baseline and the CSV data loaded,
		// let's go compare them
		summary, err := (&metricsCheck{}).check(m, thisCsv)
		if err != nil {
			log.Warnf("Check for [%s] failed [%v]", m.Name, err)
			log.Warnf(" with [%s]", summary)
			fails++
		} else {
			log.Debugf("Check for [%s] passed", m.Name)
			log.Debugf(" with [%s]", summary)
			passes++
		}

		report = append(report, summary)

		log.Debugf("Done %s", m.Name)
	}

	if fails != 0 {
		log.Warn("Overall we failed")
	}

	fmt.Printf("\n")

	// We need to find a better way here to report that some tests failed to even
	// get into the table - such as CSV file parse failures
	// Actually, now we report file failures into the report as well, we should not
	// see this - but, it is nice to leave as a sanity check.
	if len(report) < fails+passes {
		fmt.Printf("Warning: some tests (%d) failed to report\n", (fails+passes)-len(report))
	}

	// Note - not logging here - the summary goes to stdout
	fmt.Println("Report Summary:")

	table := tablewriter.NewWriter(os.Stdout)

	table.SetHeader((&metricsCheck{}).reportTitleSlice())
	for _, s := range report {
		table.Append(s)
	}
	table.Render()
	fmt.Printf("Fails: %d, Passes %d\n", fails, passes)

	// Did we see any failures during the run?
	if fails != 0 {
		err = errors.New("Failed")
	} else {
		err = nil
	}

	return
}

// checkmetrics main entry point.
// Do the command line processing, load the TOML file, and do the processing
// against the CSV files
func main() {
	app := cli.NewApp()
	app.Name = name
	app.Usage = usage

	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:  "basefile",
			Usage: "path to baseline TOML metrics file",
		},
		cli.BoolFlag{
			Name:  "debug",
			Usage: "enable debug output in the log",
		},
		cli.StringFlag{
			Name:  "log",
			Usage: "set the log file path",
		},
		cli.StringFlag{
			Name:  "metricsdir",
			Usage: "directory containing CSV metrics",
		},
	}

	app.Before = func(context *cli.Context) error {
		var err error

		if path := context.GlobalString("log"); path != "" {
			f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND|os.O_SYNC, 0640)
			if err != nil {
				return err
			}
			log.SetOutput(f)
		}

		if context.GlobalBool("debug") {
			log.SetLevel(log.DebugLevel)
		}

		if context.GlobalString("basefile") == "" {
			log.Error("Must supply basefile argument")
			return errors.New("Must supply basefile argument")
		}

		if context.GlobalString("metricsdir") == "" {
			log.Error("Must supply metricsdir argument")
			return errors.New("Must supply metricsdir argument")
		}

		ciBasefile, err = newBasefile(context.GlobalString("basefile"))

		return err
	}

	app.Action = func(context *cli.Context) error {
		return processMetrics(context)
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
