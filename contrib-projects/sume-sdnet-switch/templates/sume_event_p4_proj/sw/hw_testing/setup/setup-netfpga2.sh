#!/bin/bash

# Configure eth2 with IP addresses
ip address add 10.0.0.2/24 dev eth2
ip address add 10.0.1.2/24 dev eth2

ifconfig eth1 up
ifconfig eth2 up

# Add static ARP entries
arp -i eth2 -s 10.0.0.1 0c:c4:7a:b7:5f:92
arp -i eth2 -s 10.0.1.1 0c:c4:7a:b7:5f:93

