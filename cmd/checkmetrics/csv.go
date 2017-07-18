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

package main

import (
	"encoding/csv"
	"errors"
	"math"
	"os"
	"strconv"

	log "github.com/Sirupsen/logrus"
	"github.com/montanaflynn/stats"
)

// csvRecord holds the data for a single 'test'. Some of the data is imported
// from the CSV file, and other fields are then calculated from that data
type csvRecord struct {
	Records [][]string // The record slices imported from the file

	// All items below here are generated or calculated from the Records
	ResultStrings []string  // Hold the array of all the Results as strings
	Results       []float64 // Result array converted to floats
	Iterations    int       // How many results did we gather
	Mean          float64   // The 'average'
	MinVal        float64   // Smallest value we saw
	MaxVal        float64   // Largest value we saw
	SD            float64   // Standard Deviation
	CoV           float64   // Co-efficient of Variation
}

// load reads in a CSV 'Metrics' results file from the file path given
func (c *csvRecord) load(filepath string) error {
	var err error
	var f *os.File
	var r *csv.Reader

	log.Debugf("in csv load of [%s]", filepath)

	f, err = os.Open(filepath)
	if err != nil {
		log.Warnf("[%s][%v]", filepath, err)
		return err
	}

	defer f.Close()

	r = csv.NewReader(f)

	c.Records, err = r.ReadAll()
	if err != nil {
		log.Warnf("[%s][%v]", filepath, err)
		return err
	}

	// Check we have at least one header line and one value line
	numRecords := len(c.Records)
	if numRecords < 2 {
		log.Errorf("File [%s] only has [%d] records, need at least 2, including header", filepath, numRecords)
		return errors.New("Not enough records in file")
	}

	// The Results column for the CSV metrics files is expected to be in the 5th column
	const resultsColumn = 4

	// Sanity check that the CSV file appears to have the Result column where
	// we expect to find it
	numZeroRecords := len(c.Records[0])
	if numZeroRecords < resultsColumn+1 {
		log.Errorf("Column %d is not present (only %d columns)", resultsColumn+1, numZeroRecords)
		return errors.New("Not enough columns for Result column")
	}

	if c.Records[0][resultsColumn] != "Result" {
		log.Errorf("Column %d is [%s], not [Result]", resultsColumn+1, c.Records[0][resultsColumn])
		return errors.New("Expected Results column is not [Result]")
	}

	// Build a slice containing just the 'Result' strings
	for _, r := range c.Records {
		c.ResultStrings = append(c.ResultStrings, r[4])
	}

	// Set default min and max to infinates to ensure we pick up the values
	// from the table. Alternatively, we could just set them to the values
	// from the first entry in array.
	c.MinVal = math.Inf(1)
	c.MaxVal = math.Inf(-1)
	var total float64
	for recordno, r := range c.ResultStrings[1:] {
		c.Iterations++

		val, err := strconv.ParseFloat(r, 64)
		if err != nil {
			log.Errorf("Failed to conver float, file [%s] record [%d]", filepath, recordno)
			return err
		}

		// Build a slice of float64 result values for us to work on
		c.Results = append(c.Results, val)
		total += val

		// Remember the smallest and largest values we've seen in the data
		if val > c.MaxVal {
			c.MaxVal = val
		}

		if val < c.MinVal {
			c.MinVal = val
		}
	}

	// Calculate some basic statistics
	c.Mean = total / float64(c.Iterations)
	c.SD, _ = stats.StandardDeviation(c.Results)
	// CoV is the Coefficient of Variation - an easier way to gauge the 'spread'
	// of the data in the sample set
	// We hold it as a 'percentage'
	c.CoV = (c.SD / c.Mean) * 100.0

	log.Debugf(" Min is %f", c.MinVal)
	log.Debugf(" Max is %f", c.MaxVal)
	log.Debugf(" Mean is %f", c.Mean)
	log.Debugf(" SD is %f", c.SD)
	log.Debugf(" CoV is %.2f", c.CoV)

	return nil
}
