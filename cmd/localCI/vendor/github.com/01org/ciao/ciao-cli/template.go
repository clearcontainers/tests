//
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
//

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"regexp"
	"strings"
	"text/template"
)

const templateFunctionHelp = `
ciao-cli adds some new functions to Go's template language

- tojson outputs the specified object in json format, e.g., {{tojson .}}
- filter operates on an slice or array of structures.  It allows the caller
  to filter the input array based on the value of a single field.
  The function returns a slice containing only the objects that satisfy the
  filter, e.g.

  ciao-cli image list -f '{{$x := filter . "Protected" "true"}}{{len $x}}'

  outputs the number of protected images maintained by the image service.
- filterContains operates along the same lines as filter, but returns
  substring matches

  ciao-cli workload list -f '{{$x := filterContains . "Name" "Cloud"}}{{range $x}}{{.ID}}{{end}}'

  outputs the IDs of the workloads which have Cloud in their name.
- filterHasPrefix along the same lines as filter, but returns prefix matches
- filterHasSuffix along the same lines as filter, but returns suffix matches
- filterFolded along the same lines as filter, but  returns matches based
  on equality under Unicode case-folding
- filterRegexp along the same lines as filter, but  returns matches based
  on regular expression matching

  ciao-cli workload list -f '{{$x := filterRegexp . "Name" "^Docker[ a-zA-z]*latest$"}}{{range $x}}{{println .ID .Name}}{{end}}'

  outputs the IDs of the workloads which have Docker prefix and latest suffix
  in their name.
- select operates on a slice of structs.  It outputs the value of a specified
  field for each struct on a new line , e.g.,

  {{select . "Name"}}
`

var funcMap = template.FuncMap{
	"filter":          filterByField,
	"filterContains":  filterByContains,
	"filterHasPrefix": filterByHasPrefix,
	"filterHasSuffix": filterByHasSuffix,
	"filterFolded":    filterByFolded,
	"filterRegexp":    filterByRegexp,
	"tojson":          toJSON,
	"select":          selectField,
}

func findField(fieldPath []string, v reflect.Value) reflect.Value {
	f := v
	for _, seg := range fieldPath {
		f = f.FieldByName(seg)
		if f.Kind() == reflect.Ptr {
			f = reflect.Indirect(f)
		}
	}
	return f
}

func filterField(obj interface{}, field, val string, cmp func(string, string) bool) (retval interface{}) {
	defer func() {
		err := recover()
		if err != nil {
			fatalf("Invalid use of filter: %v", err)
		}
	}()

	list := reflect.ValueOf(obj)
	if list.Kind() == reflect.Ptr {
		list = reflect.Indirect(list)
	}
	filtered := reflect.MakeSlice(list.Type(), 0, list.Len())

	fieldPath := strings.Split(field, ".")

	for i := 0; i < list.Len(); i++ {
		v := list.Index(i)
		if v.Kind() == reflect.Ptr {
			v = reflect.Indirect(v)
		}

		f := findField(fieldPath, v)

		strVal := fmt.Sprintf("%v", f.Interface())
		if cmp(strVal, val) {
			filtered = reflect.Append(filtered, list.Index(i))
		}
	}

	retval = filtered.Interface()
	return

}

func filterByField(obj interface{}, field, val string) (retval interface{}) {
	return filterField(obj, field, val, func(a, b string) bool {
		return a == b
	})
}

func filterByContains(obj interface{}, field, val string) (retval interface{}) {
	return filterField(obj, field, val, strings.Contains)
}

func filterByFolded(obj interface{}, field, val string) (retval interface{}) {
	return filterField(obj, field, val, strings.EqualFold)
}

func filterByHasPrefix(obj interface{}, field, val string) (retval interface{}) {
	return filterField(obj, field, val, strings.HasPrefix)
}

func filterByHasSuffix(obj interface{}, field, val string) (retval interface{}) {
	return filterField(obj, field, val, strings.HasSuffix)
}

func filterByRegexp(obj interface{}, field, val string) (retval interface{}) {
	return filterField(obj, field, val, func(a, b string) bool {
		matched, err := regexp.MatchString(b, a)
		if err != nil {
			fatalf("Invalid regexp: %v", err)
		}
		return matched
	})
}

func selectField(obj interface{}, field string) string {
	defer func() {
		err := recover()
		if err != nil {
			fatalf("Invalid use of select: %v", err)
		}
	}()

	var b bytes.Buffer
	list := reflect.ValueOf(obj)
	if list.Kind() == reflect.Ptr {
		list = reflect.Indirect(list)
	}

	fieldPath := strings.Split(field, ".")

	for i := 0; i < list.Len(); i++ {
		v := list.Index(i)
		if v.Kind() == reflect.Ptr {
			v = reflect.Indirect(v)
		}

		f := findField(fieldPath, v)

		fmt.Fprintf(&b, "%v\n", f.Interface())
	}

	return string(b.Bytes())
}

func toJSON(obj interface{}) string {
	b, err := json.MarshalIndent(obj, "", "\t")
	if err != nil {
		return ""
	}
	return string(b)
}

func outputToTemplate(name, tmplSrc string, obj interface{}) error {
	t, err := template.New(name).Funcs(funcMap).Parse(tmplSrc)
	if err != nil {
		fatalf(err.Error())
	}
	if err = t.Execute(os.Stdout, obj); err != nil {
		fatalf(err.Error())
	}
	return nil
}

func createTemplate(name, tmplSrc string) *template.Template {
	var t *template.Template
	if tmplSrc == "" {
		return nil
	}

	t, err := template.New(name).Funcs(funcMap).Parse(tmplSrc)
	if err != nil {
		fatalf(err.Error())
	}

	return t
}
