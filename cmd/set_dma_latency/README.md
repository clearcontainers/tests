# set_dma_latency

## Overview

You can use the `set_dma_latency` tool to set the value of the
`/dev/cpu_dma_latency` file. This allows us to control or disable
the use of `P` and `C` states on the processor.

The ability to control `C` and `P` states is useful during metrics
evaluation as entering and leaving `C` and `P` states incurs some
overheads, which can inject noise into the metrics results.

## Detail

The program takes a single 32-bit microsecond argument, opens
the `/dev/cpu_dma_latency` file, and writes the value to that file
as a 32 bit value. The program then sleeps, as the file must be
kept open for the written value to continue to have effect.

Upon success the program prints its PID on stdout.

Upon failure the program returns with a non-zero return code.

To terminate the program, and thus close `/dev/cpu_dma_latency`
and restore the original settings, send the program a `SIGTERM`.
This can be achieved using `kill(2)` and the PID returned
by the program.

Normally you must execute the program with root privileges
to allow the program to write to the `/dev/cpu_dma_latency` file.

## Notes

If you use this program to reduce CPU power and frequency
variations, you might also want to investigate disabling 'turbo mode'.

If your system is using the `intel_pstate` driver, this can be achieved
by use of the `/sys/devices/system/cpu/intel_pstate/no_turbo` file.

## References

See the Linux kernel [pm qos](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/power/pm_qos_interface.txt)
documentation for additional information about `/dev/cpu_dma_latency` and other related
features.
