# checkmetrics

## Overview

The `checkmetrics` tool is used to check the metrics Comma Separated
Values ([CSV](https://en.wikipedia.org/wiki/Comma-separated_values))
results files against a [TOML](https://github.com/toml-lang/toml)
file that contains baseline expectations for the results.

`checkmetrics` checks for a matching CSV file for each entry in the
TOML file. Failure to find a matching CSV is classified as a failure.

`checkmetrics` will continue to process all entries in the TOML file
and print its final results in a summary table to `stdout`.

Each CSV metrics file must contain at least one header line, with the
`Results` in column 5, and at least one line containing a test result
line (that is, the minimum CSV file consists of two lines, one header
and one result value).

`checkmetrics` will exit with a failure code if any of the TOML entries
do not complete successfully.

## baseline TOML layout
The Metrics CSV files to be checked, and the range that the median of the
`Results` data is expected to fall within is defined in a TOML file.
This baseline file can be specified by command line or it is installed
in `/etc/checkmetrics/checkmetrics.toml` by default.

Each Metric has a separate `[[metric]]` section within the TOML file.

The following is an example TOML file:

```
[[metric]]
# The name of the metrics test, must match that of the generated CSV file
name = "docker-run-time"
description = "/bin/true cycle time"
# Min and Max values to set a 'range' that the median of the CSV Results data
# must fall within (inclusive)
minval = 0.5
maxval = 1.5

... and repeat for each metric ...
```

## Options
`checkmetrics` takes a number of options. Some are mandatory.

### TOML basefile path (mandatory)

```
--basefile value    path to baseline TOML metrics file
```

### Debug mode
```
--debug             enable debug output in the log
```

### Log file path
```
--log value         set the log file path
```

### Metrics CSV directory path
```
--metricsdir value  directory containing CSV metrics (mandatory)
```

### Help
```
--help, -h          show help
```

### Version
```
--version, -v       print the version
```

## Output
The `checkmetrics` tool outputs a summary table after processing all metrics/CSV
files, and will return a non-zero return code if any of the metrics checks fail.

The following example output was generated from the files detailed in the [Example](#Example)
section.

```
Report Summary:
+------+-----------+--------------------+----------------------------+---------+-------+-------+--------+
| P/F  |   NAME    |       FLOOR        |            MEAN            | CEILING | ITERS |  SD   |  COV   |
+------+-----------+--------------------+----------------------------+---------+-------+-------+--------+
| Pass | testone   |              0.500 |                      1.258 |   1.500 |     4 | 0.044 | 3.53 % |
| Fail | testtwo   |             10.000 |                      1.182 | 100.000 |     4 | 0.015 | 1.25 % |
| Fail | testthree |              0.100 |                      1.207 |   0.500 |     4 | 0.028 | 2.30 % |
| Fail | testfour  | Failed to load CSV | Not enough records in file |         |       |       |        |
+------+-----------+--------------------+----------------------------+---------+-------+-------+--------+
Fails: 3, Passes 1
Failed
```

## Usage

### Download and Build

To download and build `checkmetrics`:

```
$ repo="github.com/clearcontainers/tests/cmd/checkmetrics"
$ go get -d "$repo"
$ (cd "$GOPATH/src/$repo" && go build)
```

## Example

For example, to invoke the `checkmetrics` tool, enter:

```
BASEFILE=`pwd`/../../metrics/baseline/baseline-cor.toml
METRICSDIR=`pwd`/../../metrics/results

$ ./checkmetrics --basefile ${BASEFILE} --metricsdir ${METRICSDIR}
```
This is the example baseline TOML file used to generate the report in the
[Output](#Output) section, and used with the CSV example files below:

```
[[metric]]
name = "testone"
description = "/bin/true cycle time"
# Notionally this test does not have a minimum - smaller is better - but, if we
# get an unexpectedly low number then I think we'd like to know!
minval = 0.5
maxval = 1.5

[[metric]]
name = "testtwo"
description = "/bin/true cycle time min"
# Deliberately fail the min check
minval = 10.0
maxval = 100.0

[[metric]]
name = "testthree"
description = "/bin/true cycle time max"
# Deliberately fail the max check
minval = 0.1
maxval = 0.5

[[metric]]
name = "testfour"
description = "testing for short record file"
maxval = 1.5

```

The CSV files used to generate the summary table in the [Output](#Output) section:
Note, the data in these files is for example only.

testone.csv:
```
Timestamp,Group,Name,Args,Result,Units,System,SystemVersion,Platform,Image,Kernel,Commit
"1498645222","PNP","first test","image=busybox command=true runtime=runc units=seconds","1.31","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645224","PNP","first test","image=busybox command=true runtime=runc units=seconds","1.25","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645225","PNP","first test","image=busybox command=true runtime=runc units=seconds","1.19","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645226","PNP","first test","image=busybox command=true runtime=runc units=seconds","1.28","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
```

testtwo.csv:
```
Timestamp,Group,Name,Args,Result,Units,System,SystemVersion,Platform,Image,Kernel,Commit
"1498645232","PNP","second test","image=busybox command=true runtime=runc units=seconds","1.18","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645234","PNP","second test","image=busybox command=true runtime=runc units=seconds","1.20","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645235","PNP","second test","image=busybox command=true runtime=runc units=seconds","1.19","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645236","PNP","second test","image=busybox command=true runtime=runc units=seconds","1.16","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
```

testthree.csv:
```
Timestamp,Group,Name,Args,Result,Units,System,SystemVersion,Platform,Image,Kernel,Commit
"1498645227","PNP","third test","image=busybox command=true runtime=runc units=seconds","1.23","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645229","PNP","third test","image=busybox command=true runtime=runc units=seconds","1.24","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645230","PNP","third test","image=busybox command=true runtime=runc units=seconds","1.18","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
"1498645231","PNP","third test","image=busybox command=true runtime=runc units=seconds","1.18","s","ubuntu","16.04","Intel Core i7-4500U (2 cores)","clear-16020-containers.img","vmlinux-4.9.33-62.container","9c2b909abc5816705429d0bac2405c6e2f0c7f63"
```

testfour.csv - a file with no results lines to check for error conditions and reporting:
```
Timestamp,Group,Name,Args,Result,Units,System,SystemVersion,Platform,Image,Kernel,Commit
```
