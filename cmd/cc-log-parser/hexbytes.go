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
	"io"
	"io/ioutil"
	"os"
	"strings"
)

type HexByteReader struct {
	file string
	f    *os.File
	data []byte

	// total length of "data"
	len int

	// how much of "data" has been sent back to the caller
	offset int
}

func NewHexByteReader(file string) *HexByteReader {
	return &HexByteReader{file: file}
}

// Reader that converts "\x" to "\\x"
func (r *HexByteReader) Read(p []byte) (n int, err error) {
	size := len(p)

	if r.f == nil {
		r.f, err = os.Open(r.file)
		if err != nil {
			return 0, err
		}

		bytes := []byte{}

		// read the entire file
		bytes, err = ioutil.ReadAll(r.f)
		if err != nil {
			return 0, err
		}

		// perform the conversion
		s := string(bytes)
		result := strings.Replace(s, `\x`, `\\x`, -1)

		// store the data
		r.data = []byte(result)
		r.len = len(r.data)
		r.offset = 0
	}

	// calculate how much data is left to copy
	remaining := r.len - r.offset

	if remaining == 0 {
		return 0, io.EOF
	}

	// see how much data can be copied on this call
	limit := size

	if remaining < limit {
		limit = remaining
	}

	for i := 0; i < limit; i++ {
		// index into the stored data
		src := r.offset

		// copy
		p[i] = r.data[src]

		// update
		r.offset++
	}

	return limit, nil
}
