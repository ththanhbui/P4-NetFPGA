#!/usr/bin/env python

#
# Copyright (c) 2017 Stephen Ibanez
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


from nf_sim_tools import *
import random
from collections import OrderedDict
import sss_sdnet_tuples

###########
# pkt generation tools
###########

pktsApplied = []
pktsExpected = []

# Pkt lists for SUME simulations
nf_applied = OrderedDict()
nf_applied[0] = []
nf_applied[1] = []
nf_applied[2] = []
nf_applied[3] = []
nf_expected = OrderedDict()
nf_expected[0] = []
nf_expected[1] = []
nf_expected[2] = []
nf_expected[3] = []

nf_port_map = {"nf0":0b00000001, "nf1":0b00000100, "nf2":0b00010000, "nf3":0b01000000, "dma0":0b00000010, "none":0}
nf_id_map = {"nf0":0, "nf1":1, "nf2":2, "nf3":3}

sss_sdnet_tuples.clear_tuple_files()

def applyPkt(pkt, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt.time = time
    nf_applied[nf_id_map[ingress]].append(pkt)

def expPkt(pkt, egress, drop):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['dst_port'] = nf_port_map[egress]
    sss_sdnet_tuples.sume_tuple_expect['drop'] = drop 
    sss_sdnet_tuples.write_tuples()
    if egress in ["nf0","nf1","nf2","nf3"] and drop == False:
        nf_expected[nf_id_map[egress]].append(pkt)
    elif egress == 'bcast' and drop == False:
        nf_expected[0].append(pkt)
        nf_expected[1].append(pkt)
        nf_expected[2].append(pkt)
        nf_expected[3].append(pkt)

def write_pcap_files():
    wrpcap("src.pcap", pktsApplied)
    wrpcap("dst.pcap", pktsExpected)

    for i in nf_applied.keys():
        if (len(nf_applied[i]) > 0):
            wrpcap('nf{0}_applied.pcap'.format(i), nf_applied[i])

    for i in nf_expected.keys():
        if (len(nf_expected[i]) > 0):
            wrpcap('nf{0}_expected.pcap'.format(i), nf_expected[i])

    for i in nf_applied.keys():
        print "nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]]

#####################
# generate testdata #
#####################
MAC1 = "11:11:11:11:11:11"
MAC2 = "22:22:22:22:22:22"
sport = 55
dport = 72
IP1_src = "10.0.0.1"
IP1_dst = "10.0.0.2"
IP2_src = "192.168.1.1"
IP2_dst = "192.168.1.27"
IP3_src = "12.138.254.42"
IP3_dst = "12.138.254.33"


PKT_SIZE = 1000
MIN_PKT_SIZE = 64
HEADER_SIZE = 54 # size of TCP header

# Create a single TCP flow using the given 5-tuple parameters of the given size
def make_flow(srcIP, dstIP, sport, dport, flow_size):
    pkts = []
    # make the SYN PKT
    pkt = Ether(dst=MAC1, src=MAC2) / IP(src=srcIP, dst=dstIP) / TCP(sport=sport, dport=dport, flags='S')
    pkt = pad_pkt(pkt, MIN_PKT_SIZE)
    pkts.append(pkt)
    # make the data pkts
    size = flow_size
    while size >= PKT_SIZE:
        pkt = Ether(dst=MAC1, src=MAC2) / IP(src=srcIP, dst=dstIP) / TCP(sport=sport, dport=dport, flags='A')
        pkt = pad_pkt(pkt, PKT_SIZE + HEADER_SIZE)
        pkts.append(pkt)
        size -= PKT_SIZE
    # make the FIN pkt
    size = max(MIN_PKT_SIZE - HEADER_SIZE, size)
    pkt = Ether(dst=MAC1, src=MAC2) / IP(src=srcIP, dst=dstIP) / TCP(sport=sport, dport=dport, flags='F')
    pkt = pad_pkt(pkt, HEADER_SIZE + size)
    pkts.append(pkt)
    return pkts

# randomly interleave the flow's packets
def mix_flows(flows):
    trace = []
    for fid in range(len(flows)):
        trace = map(next, random.sample([iter(trace)]*len(trace) + [iter(flows[fid])]*len(flows[fid]), len(trace)+len(flows[fid])))
    return trace

# Create 3 flows and mix them together
flow1 = make_flow(IP1_src, IP1_dst, sport, dport, 1000)
flow2 = make_flow(IP2_src, IP2_dst, sport, dport, 20000)
flow3 = make_flow(IP3_src, IP3_dst, sport, dport, 1000)
trace = mix_flows([flow1, flow2, flow3])

# apply the trace
i = 0
drop = True
ingress = "nf0"
egress = "none"
for pkt in trace:
    applyPkt(pkt, ingress, i)
    i += 1
    expPkt(pkt, egress, drop)
    

# Final dummy pkt (not dropped) - used for barrier in SUME simulations
drop = False
pkt = Ether(dst="08:11:11:11:11:08") / IP()
pkt = pad_pkt(pkt, 64)
ingress = "nf0"
i += 1
applyPkt(pkt, ingress, i)
egress = "nf0"
expPkt(pkt, egress, drop)


write_pcap_files()

