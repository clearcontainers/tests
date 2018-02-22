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

//--------------------------------------------------------------------
// Description: Tool to read Clear Containers logfmt-formatted [*]
//   log files, sort and display by time, showing the time difference
//   between each log record.
//
//   [*] - https://brandur.org/logfmt
//
//--------------------------------------------------------------------

package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"sort"
	"strconv"
	"time"

	"github.com/go-logfmt/logfmt"
	"github.com/urfave/cli"
)

const (
	name = "cc-log-parser"

	// This is a "special" source: agent logs are actually encoded
	// within proxy logs so need to be unpacked.
	agentSourceField = "qemu"

	proxyVMField = "vm"

	// Tell time.Parse() how to handle the various logfile timestamp
	// formats by providing a number of formats for the "magic" data the
	// golang time package mandates:
	//
	//     "Mon Jan 2 15:04:05 -0700 MST 2006"
	dateFormat = "2006-01-02T15:04:05.999999999-07:00"

	// the shim doesn't use a colon in the timezone offset
	shimDateFormat = "2006-01-02T15:04:05.999999999-0700"

	// The agent encodes the timezone symbolically
	agentDateFormat = "2006-01-02T15:04:05.999999999Z"
)

var (
	// set by the build
	version = ""
	commit  = ""

	verbose = false

	// If true, do not unpack the agent log entries from their proxy log
	// entry wrapper.
	disable_agent_unpack = false
)

// parseTime attempts to convert the specified timestamp string into a Time
// object by checking it against various known timestamp formats.
func parseTime(timeString string) (time.Time, error) {
	if timeString == "" {
		return time.Time{}, errors.New("need time string")
	}

	timeFormats := []string{dateFormat, shimDateFormat, agentDateFormat}

	for _, format := range timeFormats {
		t, err := time.Parse(format, timeString)

		if err == nil {
			return t, nil
		}
	}

	return time.Time{}, fmt.Errorf("Unable to parse time %v", timeString)
}

// agentLogEntry returns true if the specified log entry is from the agent
func agentLogEntry(le LogEntry) bool {
	if le.Source != agentSourceField {
		return false
	}

	msg := le.Msg

	if msg == "" {
		return false
	}

	l := len(msg)

	// agent messages are encoded in JSON format
	if msg[0] != '{' {
		return false
	}

	if msg[l-1] != '}' {
		return false
	}

	return true
}

// unpackAgentLogEntry unpacks the proxy log entry that encodes an agent
// message and returns the agent log entry, discarding the proxy log entry
// that held it.
func unpackAgentLogEntry(l LogEntry) (LogEntry, error) {
	agent := LogEntry{}

	if l.Source != agentSourceField {
		return LogEntry{}, fmt.Errorf("agent log entry has wrong source (expected %v, got %v): %+v",
			agentSourceField, l.Source, l)
	}

	vm := l.Data[proxyVMField]
	if vm == "" {
		return LogEntry{}, fmt.Errorf("agent log entry missing %v field: %+v",
			proxyVMField, l)
	}

	if l.Msg == "" {
		return LogEntry{}, fmt.Errorf("agent log entry empty: %+v", l)
	}

	err := json.Unmarshal([]byte(l.Msg), &agent)
	if err != nil {
		return LogEntry{}, fmt.Errorf("agent log entry unpack failed for %+v: %v", l, err)
	}

	// Supplement the agent entry with a few extra details
	agent.Source = agentSourceField
	agent.Filename = l.Filename
	agent.Line = l.Line

	return agent, nil
}

// createLogEntry converts a logfmt record into a LogEntry
func createLogEntry(filename string, line uint64, d *logfmt.Decoder) (LogEntry, error) {
	l := LogEntry{}

	l.Filename = filename
	l.Line = line
	l.Data = make(map[string]string)

	for d.ScanKeyval() {
		key := string(d.Key())
		value := string(d.Value())

		switch key {
		case "level":
			l.Level = value

		case "msg":
			l.Msg = value

		case "name":
			l.Name = value

		case "pid":
			pid, err := strconv.Atoi(value)
			if err != nil {
				return LogEntry{}, fmt.Errorf("failed to parse pid for %v:%v:%v", key, value, err)
			}

			l.Pid = pid

		case "source":
			l.Source = value

		case "time":
			t, err := parseTime(value)
			if err != nil {
				return LogEntry{}, fmt.Errorf("failed to parse time for %v:%v:%v", key, value, err)
			}

			l.Time = t

		default:
			// non-standard fields are stored here
			l.Data[key] = value
		}
	}

	if !disable_agent_unpack && agentLogEntry(l) {
		agent, err := unpackAgentLogEntry(l)
		if err != nil {
			return LogEntry{}, err
		}

		// the agent log entry totally replaces the proxy log entry
		// that encapsulated it.
		l = agent
	}

	return l, nil
}

// parseLogFile reads a logfmt format logfile and converts it into log
// entries.
func parseLogFile(file string) (LogEntries, error) {
	var entries LogEntries

	// logfmt is unhappy attempting to read hex-encoded bytes in strings,
	// so hide those from it by escaping them.
	r := NewHexByteReader(file)

	d := logfmt.NewDecoder(r)

	line := uint64(0)

	for d.ScanRecord() {
		line++
		entry, err := createLogEntry(file, line, d)
		if err != nil {
			return LogEntries{}, err
		}

		entries = append(entries, entry)
	}

	if d.Err() != nil {
		return LogEntries{}, d.Err()
	}

	return entries, nil
}

// processLogFiles parses all log files, sorts the results by timestamp and
// returns the collated results
func processLogFiles(files []string) (LogEntries, error) {
	var entries LogEntries

	for _, file := range files {
		e, err := parseLogFile(file)
		if err != nil {
			return LogEntries{}, err
		}

		entries = append(entries, e...)
	}

	sort.Sort(entries)

	return entries, nil
}

func displayLogEntries(entries LogEntries) {
	for i := 0; i < len(entries); i++ {
		this := &entries[i]

		if i != 0 {
			// only calculate time difference for 2nd and
			// subsequent records as the first record doesn't have
			// a record before it :)
			prev := &entries[i-1]

			this.TimeDelta = this.Time.Sub(prev.Time)
		}

		if verbose {
			fmt.Printf("Entry %d: Delta: %d, LogEntry: %+v\n", i, this.TimeDelta, *this)
		} else {
			fmt.Printf("Entry %d: Delta: %d, LogEntry: %+v\n", i, this.TimeDelta, this.CCLogEntry)
		}
	}
}

func handleLogFiles(c *cli.Context) error {
	entries, err := processLogFiles(c.Args())
	if err != nil {
		return err
	}

	displayLogEntries(entries)

	return nil
}

func main() {
	cli.VersionPrinter = func(c *cli.Context) {
		fmt.Fprintln(os.Stdout, c.App.Version)
	}

	app := cli.NewApp()
	app.Name = name
	app.Version = fmt.Sprintf("%s %s (commit %v)", name, version, commit)
	app.Description = "tool to collate logfmt-format log files"
	app.Usage = app.Description
	app.UsageText = fmt.Sprintf("%s [options] file ...", app.Name)
	app.Flags = []cli.Flag{
		cli.BoolFlag{
			Name:        "verbose",
			Usage:       "Display full details",
			Destination: &verbose,
		},
		cli.BoolFlag{
			Name:        "no-agent-unpack",
			Usage:       "Do not unpack agent log entries",
			Destination: &disable_agent_unpack,
		},
	}

	app.Action = handleLogFiles

	err := app.Run(os.Args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
}
