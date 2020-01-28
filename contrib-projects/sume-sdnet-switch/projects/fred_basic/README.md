
# Basic Fair-RED (FRED) Prototype

This directory contains the source code used for the 2019 P4 Workshop
demo: [Event-Driven Packet Processing using P4->NetFPGA](https://p4.org/events/2019-05-01-p4-workshop/)
Here is the [abstract](https://p4.org/assets/P4WS_2019/p4workshop19-final22.pdf).
A PDF of the poster used to present the demo is also located in this
directory: fred-demo-poster.pdf

The P4 program in the `src` folder implements a simple version of the
FRED AQM policy and is written for the SUME Event Switch architecture.

The P4 program uses enqueue and dequeue events to compute per-active-flow
buffer occupancy and then compares the buffer occupancy to static threshold
values (detemined by a table lookup) to decide whether or not to drop each
packet.

The program also implements buffer occupancy tracing. That is, it uses
timer events to periodically generate packets which then read the buffer
occupancy state and report the sample to an attached monitor if the current
sample is different from the previous sample. This enables the monitor to
trace the buffer occupancy without overwhelming it with redundant
information.

