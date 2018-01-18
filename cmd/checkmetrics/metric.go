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

// Repo represents the repository under test
// The members are Public so the toml reflection can see them, but I quite
// like the lower case toml naming, hence we use the annotation strings to
// get the parser to look for lower case.
type metrics struct {
	Name        string  `toml:"name"`
	Description string  `toml:"description"`
	MinVal      float64 `toml:"minval"`
	MaxVal      float64 `toml:"maxval"`
	Gap         float64 // What is the % gap between the Min and Max vals
}
