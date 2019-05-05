#!/bin/bash

tcpdump -i eth1 -w log.pcap -B 1000000 -c 1000000

