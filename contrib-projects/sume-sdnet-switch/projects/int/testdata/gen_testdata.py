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
from int_headers import *

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

nf_port_map = {"nf0":0b00000001, "nf1":0b00000100, "nf2":0b00010000, "nf3":0b01000000, "dma0":0b00000010}
nf_id_map = {"nf0":0, "nf1":1, "nf2":2, "nf3":3}

sss_sdnet_tuples.clear_tuple_files()


def applyPkt(pkt, ingress, time, extra_len):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt) + extra_len 
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt.time = time
    nf_applied[nf_id_map[ingress]].append(pkt)

def expPkt(pkt, egress):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['dst_port'] = nf_port_map[egress]
    sss_sdnet_tuples.write_tuples()
    if egress in ["nf0","nf1","nf2","nf3"]:
        nf_expected[nf_id_map[egress]].append(pkt)
    elif egress == 'bcast':
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
MAC_addr = {}
MAC_addr["nf0"] = "08:11:11:11:11:08"
MAC_addr["nf1"] = "08:22:22:22:22:08"
MAC_addr["nf2"] = "08:33:33:33:33:08"
MAC_addr["nf3"] = "08:44:44:44:44:08"

IP_addr = {}
IP_addr["nf0"] = "10.0.0.10"
IP_addr["nf1"] = "10.0.0.11"
IP_addr["nf2"] = "10.0.0.12"
IP_addr["nf3"] = "10.0.0.13"

SWITCH_ID = 0
DATA_SIZE = len(INT_data())
MIN_PKT_SIZE = 64

"""
Create an INT packet.
data - a list of INT data to insert in packet
size - the size the packet should be padded to
"""
def make_INT_pkt(ingress, egress, icnt, max_hop, total_hop, instr_mask, data, size):
    pkt = Ether(dst=MAC_addr[egress], src=MAC_addr[ingress]) / \
          INT(ins_cnt=icnt, max_hop_cnt=max_hop, total_hop_cnt=total_hop, instruction_bitmask=instr_mask)

    for i in range(len(data)):
        if i == len(data)-1:
            pkt = pkt / INT_data(bos=1, data=data[i])
        else:
            pkt = pkt / INT_data(bos=0, data=data[i])

    return pad_pkt(pkt, size)

i = 0
ingress = "nf0"
egress = "nf1"

# pkt 1
ins_cnt = 1
pkt_in = make_INT_pkt(ingress, egress, ins_cnt, 10, 0, SWITCH_ID_MASK, [], MIN_PKT_SIZE)
i += 1
extra_len = ins_cnt*DATA_SIZE
applyPkt(pkt_in, ingress, i, extra_len)
pkt_out = make_INT_pkt(ingress, egress, ins_cnt, 10, 1, SWITCH_ID_MASK, 
         [SWITCH_ID], len(pkt_in)+extra_len)
expPkt(pkt_out, egress)

# pkt 2
ins_cnt = 2
pkt_in = make_INT_pkt(ingress, egress, ins_cnt, 10, 0, (INGRESS_PORT_ID_MASK ^ EGRESS_PORT_ID_MASK), [], MIN_PKT_SIZE)
i += 1
extra_len = ins_cnt*DATA_SIZE
applyPkt(pkt_in, ingress, i, extra_len)
pkt_out = make_INT_pkt(ingress, egress, ins_cnt, 10, 1, (INGRESS_PORT_ID_MASK ^ EGRESS_PORT_ID_MASK), 
         [nf_port_map[ingress], nf_port_map[egress]], len(pkt_in)+extra_len)
expPkt(pkt_out, egress)

# pkt 3
ins_cnt = 3
pkt_in = make_INT_pkt(ingress, egress, ins_cnt, 10, 0, (SWITCH_ID_MASK ^ INGRESS_PORT_ID_MASK ^ EGRESS_PORT_ID_MASK), [], MIN_PKT_SIZE)
i += 1
extra_len = ins_cnt*DATA_SIZE
applyPkt(pkt_in, ingress, i, extra_len)
pkt_out = make_INT_pkt(ingress, egress, ins_cnt, 10, 1, (SWITCH_ID_MASK ^ INGRESS_PORT_ID_MASK ^ EGRESS_PORT_ID_MASK), 
         [SWITCH_ID, nf_port_map[ingress], nf_port_map[egress]], len(pkt_in)+extra_len)
expPkt(pkt_out, egress)


write_pcap_files()

