#!/usr/bin/env python

#
# Copyright (c) 2019 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#
# Author:
#        Modified by Neelakandan Manihatty Bojan, Georgina Kalogeridou

import logging
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)

from NFTest import *
import sys
import os
import json
#from scapy.layers.all import Ether, IP, TCP
from scapy.all import *

import config_writes

PERIOD = 5 # increments of 20ns
# map interface names to numerical values
NF_PORT_MAP = {'nf0':0b00000001, 'nf1':0b00000100, 'nf2':0b00010000, 'nf3':0b01000000}
# Time to start sending packets
BASE_TIME = 10e-6

phy2loop0 = ('../connections/conn', [])
nftest_init(sim_loop = [], hw_config = [phy2loop0])

print "About to start the test"

nftest_start()

# read the externs defined in the P4 program
EXTERN_DEFINES_FILE = os.path.expandvars('$P4_PROJECT_DIR/testdata/SimpleSumeSwitch_extern_defines.json')
with open(EXTERN_DEFINES_FILE) as f:
    p4_externs = json.load(f)

def schedule_pkts(pkt_list, iface, start_time, rate):
    """
    pkt_list: list of packets to schedule
    iface: the interface to schedule the packets onto (e.g. nf0, nf1, etc.)
    start_time: the time at which the first packet should be scheduled
    rate: rate at which to schedule packets (Gbps)
    """
    rate = rate*(10**9)/8.0 # convert to Bps
    for pkt in pkt_list:
        pkt.time = start_time
        start_time += (len(pkt)+8+12)/rate
        pkt.tuser_sport = NF_PORT_MAP[iface]

def make_ip_pkts(srcIP, dstIP, srcMAC, dstMAC, pkt_len, num_pkts):
    result = []
    for i in range(num_pkts):
        pkt = Ether(src=srcMAC, dst=dstMAC) / IP(src=srcIP, dst=dstIP)
        pkt = pkt / ('\x00'*(pkt_len - len(pkt)))
        result.append(pkt)
    return result

# configure the tables in the P4_SWITCH
nftest_regwrite(0x440200f0, 0x00000001)
nftest_regwrite(0x440200f0, 0x00000001)
nftest_regwrite(0x440200f0, 0x00000001)
nftest_regwrite(0x440200f0, 0x00000001)
nftest_regwrite(0x440200f0, 0x00000001)
config_writes.config_tables()

# configure period of the timer events
nftest_regwrite(p4_externs['period']['base_addr'], PERIOD)

IP1 = '10.0.0.1'
IP2 = '10.0.0.2'
MAC1 = '08:00:00:00:00:01'
MAC2 = '08:00:00:00:00:02'

PKT_LEN = 64 # bytes
NUM_PKTS = 20
RATE = 2 # Gbps

nf0_pkts = make_ip_pkts(IP1, IP2, MAC1, MAC2, PKT_LEN, NUM_PKTS)

schedule_pkts(nf0_pkts, 'nf0', BASE_TIME, RATE)

# Apply the packets
nftest_send_phy('nf0', nf0_pkts)
nftest_expect_phy('nf1', nf0_pkts)

nftest_barrier()

mres=[]
nftest_finish(mres)

