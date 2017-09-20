# Clear Containers metrics tests

This section contains a collection of scripts designed to measure the performance
and responsiveness of the different components which form Clear Containers.

## Metrics tests - content

The tests are organized in the following sections:

| Section   | Short description
| ----------| --------------------------------------------------------------------------------
| density   | Measure the amount of memory used by N containers under different configurations.
| network   | Measure a set of network essentials such as: bandwidth, jitter, latency, etc.
| storage   | Measure storage bandwith using different configurations.
| time      | Measure the latency of a container[s] executing a defined workload.

## Execute metrics scripts

The metrics directory includes a helper script `run_all_metrics.sh`. This helper script allows
you to execute either all metrics tests together, or a specific section at time.

NOTE: Some metrics tests require root access to run correctly.

## Options

If no options are specified, `run_all_metrics.sh` will execute all tests by default.

### Run the metrics tests from the time section only

```
-l, --latency  Run latency/time metrics tests
```

### Run the metrics tests from the density section only

```
-m,  --memory  Run memory metrics tests
```

### Run the metrics tests from the network section only

```
-n, --network  Run network metrics tests
```

### Run the metrics tests from the storage section only

```
-s, --storage  Run I/O storage metrics tests
```

### Help

```
-h, --help     show help
```

## Usage

```bash
$ sudo ./run_all_metrics.sh [options]
```

## Example

Only execute the storage metrics tests

```bash
$ sudo ./run_all_metrics.sh --storage
```
