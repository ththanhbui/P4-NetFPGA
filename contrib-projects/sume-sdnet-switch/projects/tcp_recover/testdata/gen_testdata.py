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
from digest_data import *

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

def applyPkt(pkt, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt) 
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt) 
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt.time = time
    nf_applied[nf_id_map[ingress]].append(pkt)

def expPkt(pkt, egress, drop, **kwargs):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['dst_port'] = nf_port_map[egress]
    sss_sdnet_tuples.sume_tuple_expect['drop'] = drop 
    if 'flow_id' in kwargs:
        sss_sdnet_tuples.dig_tuple_expect['flow_id'] = kwargs['flow_id'] # 792281630049477301766976897099
    if 'tuser' in kwargs:
        sss_sdnet_tuples.dig_tuple_expect['tuser'] = kwargs['tuser'] 
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
        print ("nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]])

######################
# Defining functions #
###################### 

MAC1 = "08:11:11:11:11:08" # --> nf0
MAC2 = "08:22:22:22:22:08" # --> nf1
sport = 55
dport = 75
IP1_src = "10.0.0.1"
IP1_dst = "10.0.0.2"
IP2_src = "192.168.1.1"
IP2_dst = "192.168.1.27"
IP3_src = "12.138.254.42"
IP3_dst = "12.138.254.33"


# Create a single TCP flow using the given 5-tuple parameters of the given size
def make_flow(srcIP, dstIP, sport, dport, flow_size):
    pkts = []
    # make the SYN PKT
    pkt = Ether(dst=MAC1, src=MAC2) / IP(src=srcIP, dst=dstIP) / TCP(sport=sport, dport=dport, flags='S')
    pkt = pad_pkt(pkt, PKT_SIZE)
    pkts.append(pkt)
    # make the data pkts
    size = flow_size
    while size >= PKT_SIZE:
        pkt = Ether(dst=MAC1, src=MAC2) / IP(src=srcIP, dst=dstIP) / TCP(sport=sport, dport=dport, flags='A')
        pkt = pad_pkt(pkt, PKT_SIZE + HEADER_SIZE)
        pkts.append(pkt)
        size -= PKT_SIZE
    # make the FIN pkt
    size = max(PKT_SIZE - HEADER_SIZE, size)
    pkt = Ether(dst=MAC1, src=MAC2) / IP(src=srcIP, dst=dstIP) / TCP(sport=sport, dport=dport, flags='F')
    pkt = pad_pkt(pkt, HEADER_SIZE + size)
    pkts.append(pkt)
    return pkts

# # randomly interleave the flow's packets
# def mix_flows(flows):
#     trace = []
#     for fid in range(len(flows)):
#         trace = map(next, random.sample([iter(trace)]*len(trace) + [iter(flows[fid])]*len(flows[fid]), len(trace)+len(flows[fid])))
#     return trace

# # Create 3 flows and mix them together
# flow1 = make_flow(IP1_src, IP1_dst, sport, dport, 1000)
# flow2 = make_flow(IP2_src, IP2_dst, sport, dport, 20000)
# flow3 = make_flow(IP3_src, IP3_dst, sport, dport, 1000)
# trace = mix_flows([flow1, flow2, flow3])

# # apply the trace
# i = 0
# drop = True
# ingress = "nf0"
# egress = "none"
# for pkt in trace:
#     applyPkt(pkt, ingress, i)
#     i += 1
#     expPkt(pkt, egress, drop) 


#####################
# Generate testdata #
#####################

PKT_SIZE = 1024
HEADER_SIZE = 54 # size of headers
initial_seq = random.randint(0,10)
curr_seq = initial_seq
pktCnt=0


############################################
# Test P4 program with different scenarios #
############################################

# Test 1: Basic packet forwarding of the SimpleSumeSwitch-architecture-based program
# Goal: A packet coming through the SSS architecture will come out with the digest_data modified.
# Description:
#   - Send 1 packet from port 0 to port 1.
#   - Expect 1 packet coming out of port 1 of the SSS with the digest_data.flow_id computed and matches the flow_id 
#   of the original packet, and the digest_data.tuser set to write the packet to the cache queue of port 1

pkt = Ether(src=MAC1, dst=MAC2) / IP(src=IP1_src, dst=IP1_dst) / TCP(sport=sport, dport=dport, seqflags='S', seq=curr_seq)
pkt = pad_pkt(pkt, PKT_SIZE)
applyPkt(pkt, "nf0", pktCnt)                                    # send from port 0
pktCnt += 1

flow_id = compute_tuple(IP1_src,IP1_dst,6,sport,dport)
actions = compute_tuser(0,0,0,nf_port_map["nf1"])               # CACHE_WRITE to port 1
expPkt(pkt, "nf1", drop=False, flow_id=flow_id, tuser=actions)


############################################################################################################################

# Test 2: Behaviour of the program when it receives a standard ACK packet.
# Goal: When the program receives an ACK packet with an ACK Number that is the next byte expected (next Sequence Number), it 
#   drops the packets that are currently cached in the cache queue.
# Description:
#   - Send 3 packets from port 0 to port 1.
#   - Send 1 ACK packet `ack_pkt_1` acknowledged the receipt of the first packet.
#   - Expect `ack_pkt_1` to come out of the program with its digest_data.tuser set to drop 1 packet from the cache queue of 
#  port 0
#   - Send 1 ACK packet `ack_pkt_all` acknowledged the receipt of the remaining two packets.
#   - Expect `ack_pkt_all` to come out of the program with its digest_data.tuser set to drop all remaining packets from the 
#  cache queue of port 0

curr_seq += PKT_SIZE
pkt1 = Ether(src=MAC1, dst=MAC2) / IP(src=IP1_src, dst=IP1_dst) / TCP(sport=sport, dport=dport, seq=curr_seq)
pkt1 = pad_pkt(pkt, PKT_SIZE)
applyPkt(pkt1, "nf0", pktCnt)
pktCnt += 1
actions = compute_tuser(0,0,0,nf_port_map["nf1"])          # CACHE_WRITE to port 1
expPkt(pkt1, "nf1", drop=False, flow_id=flow_id, tuser=actions)

curr_seq += PKT_SIZE
pkt2 = Ether(src=MAC1, dst=MAC2) / IP(src=IP1_src, dst=IP1_dst) / TCP(sport=sport, dport=dport, seq=curr_seq)
pkt2 = pad_pkt(pkt, PKT_SIZE)
applyPkt(pkt2, "nf0", pktCnt)
pktCnt += 1
actions = compute_tuser(0,0,0,nf_port_map["nf1"])          # CACHE_WRITE to port 1
expPkt(pkt2, "nf1", drop=False, flow_id=flow_id, tuser=actions)

ack_pkt_1 = Ether(src=MAC2, dst=MAC1) / IP(src=IP1_dst, dst=IP1_src) / TCP(sport=dport, dport=sport, flags='A', 
    ack=initial_seq + PKT_SIZE*1)                            # ACK-ing the first packet
applyPkt(ack_pkt_1, "nf1", pktCnt)
pktCnt += 1                        
actions = compute_tuser(1,nf_port_map["nf1"],0,0)           # CACHE_DROP one cached packet from port 1
expPkt(ack_pkt_1, "nf0", drop=False, flow_id=flow_id, tuser=actions) 


ack_pkt_all = Ether(src=MAC2, dst=MAC1) / IP(src=IP1_dst, dst=IP1_src) / TCP(sport=dport, dport=sport, flags='A',
    ack=initial_seq + PKT_SIZE*3)
applyPkt(ack_pkt_all, "nf1", pktCnt)
pktCnt += 1
actions = compute_tuser(2,nf_port_map["nf1"],0,0)          # CACHE_DROP the remaining cached packets (2) from port 1           
expPkt(ack_pkt_all, "nf0", drop=False, flow_id=flow_id, tuser=actions)


############################################################################################################################

# Test 3: Behaviour of the program when a DUP ACK packet is received
# Goal: When there are DUP ACK packets received, the program assists the fast recovery mechanism: the third DUP ACK packet will 
#   be sent to the source with ACK flag = 0, and the program will resend the packet with Sequence Number equals to the DUP ACK.
# Description:
#   - Send 1 packet from port 0 to port 1
#   - Send 3 DUP ACK packets from port 1 to port 0
#   - Expect the 3rd DUP ACK to be sent back to source:
#      - with ACK flag set to 0
#      - digest_data.tuser is set to signal the resending of packet with Sequence Number equals to the DUP ACK.

curr_seq += PKT_SIZE
pkt1 = Ether(src=MAC1, dst=MAC2) / IP(src=IP1_src, dst=IP1_dst) / TCP(sport=sport, dport=dport, seq=curr_seq)
pkt1 = pad_pkt(pkt, PKT_SIZE)
applyPkt(pkt1, "nf0", time=1)
flow_id = compute_tuple(IP1_src,IP1_dst,6,sport,dport)
actions = compute_tuser(0,0,0,nf_port_map["nf1"])          # CACHE_WRITE to port 1
expPkt(pkt, "nf1", drop=False, flow_id=flow_id, tuser=actions)


dup_ack = Ether(src=MAC2, dst=MAC1) / IP(src=IP1_dst, dst=IP1_src) / TCP(sport=dport, dport=sport, flags='A', 
    ack=curr_seq)
applyPkt(dup_ack, "nf1", pktCnt)                           # the first DUP ACK from port 1 to port 0
pktCnt += 1
applyPkt(dup_ack, "nf1", pktCnt)                           # the second DUP ACK from port 1 to port 0
pktCnt += 1
applyPkt(dup_ack, "nf1", pktCnt)                           # the third DUP ACK from port 1 to port 0 -- fast retransmit
pktCnt += 1


expPkt(dup_ack, "nf0", drop=False, flow_id=flow_id, tuser=actions)  # the first DUP ACK from port 1 to port 0   
expPkt(dup_ack, "nf0", drop=False, flow_id=flow_id, tuser=actions)  # the second DUP ACK from port 1 to port 0

# the third DUP ACK from port 1 to port 0 -- fast retransmit: packet sent back to host with ACK flag set to 0.
dup_ack1 = Ether(src=MAC2, dst=MAC1) / IP(src=IP1_dst, dst=IP1_src) / TCP(sport=dport, dport=sport, ack=initial_seq+PKT_SIZE)
actions = compute_tuser(0,0,nf_port_map["nf1"],0)                   # CACHE_READ the cached packet from port 1           
expPkt(dup_ack1, "nf0", drop=False, flow_id=flow_id, tuser=actions)


############################################################################################################################

# Test 4: Behaviour of the program when there are multiple flows.
# Goal: After caching  are multiple flows, the program only process those packets with the flow matches the specific flow_id(s)
# that we are interested in, and have specified with our `retransmit` table in `commands.txt`.
# # Description:
#   - Create 3 flows and randomly interleave the flows' packets
#   - Expect to see that the program will process the other two flows as per normal, while assisting the fast recovery process of our flow of interest.


write_pcap_files()
