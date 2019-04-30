#!/bin/bash

# Configure eth2 with IP address
ip address add 10.0.0.1/24 dev eth2
# Configure eth3 with IP address
ip address add 10.0.1.1/24 dev eth3

ifconfig eth2 up
ifconfig eth3 up

# Add static ARP entries
arp -i eth2 -s 10.0.0.2 0c:c4:7a:8e:01:97
arp -i eth3 -s 10.0.1.2 0c:c4:7a:8e:01:97

