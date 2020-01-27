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

nf_port_map = {
    "nf0": 0b00000001,
    "nf1": 0b00000100,
    "nf2": 0b00010000,
    "nf3": 0b01000000,
    "dma0": 0b00000010,
}
tuser_map = {
    "nf0": 0b00000001,
    "nf1": 0b00000010,
    "nf2": 0b00000100,
    "nf3": 0b00001000,
    "dma0": 0b00010000,
}
nf_id_map = {"nf0": 0, "nf1": 1, "nf2": 2, "nf3": 3}

sss_sdnet_tuples.clear_tuple_files()


def applyPkt(pkt, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in["pkt_len"] = len(pkt)
    sss_sdnet_tuples.sume_tuple_in["src_port"] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect["pkt_len"] = len(pkt)
    sss_sdnet_tuples.sume_tuple_expect["src_port"] = nf_port_map[ingress]
    pkt.time = time
    nf_applied[nf_id_map[ingress]].append(pkt)


def expPkt(pkt, egress, drop, **kwargs):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect["dst_port"] = nf_port_map[egress]
    sss_sdnet_tuples.sume_tuple_expect["drop"] = drop
    if "flow_id" in kwargs:
        sss_sdnet_tuples.dig_tuple_expect["flow_id"] = kwargs[
            "flow_id"
        ]  # 792281630049477301766976897099
    if "tuser" in kwargs:
        sss_sdnet_tuples.dig_tuple_expect["tuser"] = kwargs["tuser"]
    sss_sdnet_tuples.write_tuples()

    if egress in ["nf0", "nf1", "nf2", "nf3"] and drop == False:
        nf_expected[nf_id_map[egress]].append(pkt)
    elif egress == "bcast" and drop == False:
        nf_expected[0].append(pkt)
        nf_expected[1].append(pkt)
        nf_expected[2].append(pkt)
        nf_expected[3].append(pkt)


def write_pcap_files():
    wrpcap("src.pcap", pktsApplied)
    wrpcap("dst.pcap", pktsExpected)

    for i in nf_applied.keys():
        if len(nf_applied[i]) > 0:
            wrpcap("nf{0}_applied.pcap".format(i), nf_applied[i])

    for i in nf_expected.keys():
        if len(nf_expected[i]) > 0:
            wrpcap("nf{0}_expected.pcap".format(i), nf_expected[i])

    for i in nf_applied.keys():
        print("nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]])


######################
# Defining functions #
######################

MAC1 = "00:0f:53:44:64:a0"  # --> nf-test209 eth1 -- port 0 --> 1
MAC2 = "f8:f2:1e:42:dd:0c"  # --> nf-test100 eth1 -- port 1 --> 0
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
    curr_seq = 7
    pkts = []
    # make the SYN PKT
    pkt = (
        Ether(src=MAC1, dst=MAC2)
        / IP(src=srcIP, dst=dstIP)
        / TCP(sport=sport, dport=dport, flags="S", seq=curr_seq)
    )
    pkt = pad_pkt(pkt, PKT_SIZE)
    pkts.append(pkt)
    # make the data pkts
    size = flow_size
    while size >= PKT_SIZE:
        curr_seq += PKT_SIZE
        pkt = (
            Ether(src=MAC1, dst=MAC2)
            / IP(src=srcIP, dst=dstIP)
            / TCP(sport=sport, dport=dport, flags="", seq=curr_seq)
        )
        pkt = pad_pkt(pkt, PKT_SIZE)
        pkts.append(pkt)
        size -= PKT_SIZE
    # make the FIN pkt
    curr_seq += PKT_SIZE
    pkt = (
        Ether(src=MAC1, dst=MAC2)
        / IP(src=srcIP, dst=dstIP)
        / TCP(sport=sport, dport=dport, flags="F", seq=curr_seq)
    )
    pkt = pad_pkt(pkt, PKT_SIZE)
    pkts.append(pkt)
    return pkts


# randomly interleave the flow's packets
def mix_flows(flows):
    trace = []
    for fid in range(len(flows)):
        trace = map(
            next,
            random.sample(
                [iter(trace)] * len(trace) + [iter(flows[fid])] * len(flows[fid]),
                len(trace) + len(flows[fid]),
            ),
        )
    return trace


#####################
# Generate testdata #
#####################

PKT_SIZE = 64
HEADER_SIZE = 54  # size of headers
initial_seq = 5
curr_seq = initial_seq
pktCnt = 0


############################################
# Test P4 program with different scenarios #
############################################

# Test #1: Basic packet forwarding of the SimpleSumeSwitch-architecture-based P4 program
# Goal: A packet coming through the SSS architecture will come out with the digest_data modified.
# Description:
#   - Send 1 packet from port 0 to port 1.
#   - Expect 1 packet coming out of port 1 of the SSS with the digest_data.flow_id computed and matches the flow_id
#   of the original packet, and the digest_data.tuser set to write the packet to the cache queue of port 1

pkt = (
    Ether(src=MAC1, dst=MAC2)
    / IP(src=IP1_src, dst=IP1_dst)
    / TCP(sport=sport, dport=dport, flags="S", seq=curr_seq)
)
pkt = pad_pkt(pkt, PKT_SIZE)
applyPkt(pkt, "nf0", pktCnt)  # send from port 0
pktCnt += 1

flow_id = compute_flow_number(IP1_src, IP1_dst, 6, sport, dport)
actions = compute_tuser(0, 0, 0, tuser_map["nf1"])  # CACHE_WRITE to port 1
expPkt(pkt, "nf1", drop=False, flow_id=flow_id, tuser=actions)


############################################################################################################################

# Test #2: Behaviour of the program when it receives a standard ACK packet.
# Goal: When the program receives an ACK packet with an ACK Number that is the next byte expected (next Sequence Number), it
#   drops the packets that are currently cached in the cache queue.
# Description:
#   - Send 3 packets from port 0 to port 1.
#   - Send 1 ACK packet `ack_pkt_1` acknowledged the receipt of the first packet.
#   - Expect `ack_pkt_1` to come out of the program with its digest_data.tuser set to drop 1 packet from the cache queue of
#  port 1
#   - Send 1 ACK packet `ack_pkt_all` acknowledged the receipt of the remaining two packets.
#   - Expect `ack_pkt_all` to come out of the program with its digest_data.tuser set to drop all remaining packets from the
#  cache queue of port 1

curr_seq += PKT_SIZE
pkt1 = (
    Ether(src=MAC1, dst=MAC2)
    / IP(src=IP1_src, dst=IP1_dst)
    / TCP(sport=sport, dport=dport, flags="", seq=curr_seq)
)
pkt1 = pad_pkt(pkt1, PKT_SIZE)
applyPkt(pkt1, "nf0", pktCnt)
pktCnt += 1
actions = compute_tuser(0, 0, 0, tuser_map["nf1"])  # CACHE_WRITE to port 1
expPkt(pkt1, "nf1", drop=False, flow_id=flow_id, tuser=actions)

curr_seq += PKT_SIZE
pkt2 = (
    Ether(src=MAC1, dst=MAC2)
    / IP(src=IP1_src, dst=IP1_dst)
    / TCP(sport=sport, dport=dport, flags="", seq=curr_seq)
)
pkt2 = pad_pkt(pkt2, PKT_SIZE)
applyPkt(pkt2, "nf0", pktCnt)
pktCnt += 1
actions = compute_tuser(0, 0, 0, tuser_map["nf1"])  # CACHE_WRITE to port 1
expPkt(pkt2, "nf1", drop=False, flow_id=flow_id, tuser=actions)

ack_pkt_1 = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="A", ack=initial_seq + PKT_SIZE * 1)
)  # ACK-ing the first packet
ack_pkt_1 = pad_pkt(ack_pkt_1, PKT_SIZE)
applyPkt(ack_pkt_1, "nf1", pktCnt)
pktCnt += 1
actions = compute_tuser(
    1, tuser_map["nf1"], 0, 0
)  # CACHE_DROP one cached packet from port 1
expPkt(ack_pkt_1, "nf0", drop=False, flow_id=flow_id, tuser=actions)


ack_pkt_all = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="A", ack=curr_seq + PKT_SIZE)
)
ack_pkt_all = pad_pkt(ack_pkt_all, PKT_SIZE)
applyPkt(ack_pkt_all, "nf1", pktCnt)
pktCnt += 1
actions = compute_tuser(
    2, tuser_map["nf1"], 0, 0
)  # CACHE_DROP the remaining cached packets (2) from port 1
expPkt(ack_pkt_all, "nf0", drop=False, flow_id=flow_id, tuser=actions)


############################################################################################################################

# Test #3: Behaviour of the program when three DUP ACK packets are received.
# Goal: When there are DUP ACK packets received, the program exhibits the fast retransmit mechanism: the third DUP ACK packet
#   will be sent to the source with ACK flag = 0, and the program will resend the packet with Sequence Number equals to the
#   DUP ACK.
# Description:
#   - Send 1 packet from port 0 to port 1
#   - Send 3 DUP ACK packets from port 1 to port 0
#   - Expect the 3rd DUP ACK to be sent back to source:
#      - with ACK flag set to 0
#      - digest_data.tuser is set to signal the resending of packet with Sequence Number equals to the DUP ACK.

curr_seq += PKT_SIZE
pkt3 = (
    Ether(src=MAC1, dst=MAC2)
    / IP(src=IP1_src, dst=IP1_dst)
    / TCP(sport=sport, dport=dport, flags="", seq=curr_seq)
)
pkt3 = pad_pkt(pkt3, PKT_SIZE)
applyPkt(pkt3, "nf0", pktCnt)
pktCnt += 1
actions = compute_tuser(0, 0, 0, tuser_map["nf1"])  # CACHE_WRITE to port 1
expPkt(pkt3, "nf1", drop=False, flow_id=flow_id, tuser=actions)


dup_ack1 = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="A", ack=curr_seq)
)
dup_ack1 = pad_pkt(dup_ack1, PKT_SIZE)
applyPkt(dup_ack1, "nf1", pktCnt)  # the first DUP ACK from port 1 to port 0
pktCnt += 1

dup_ack2 = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="A", ack=curr_seq)
)
dup_ack2 = pad_pkt(dup_ack2, PKT_SIZE)
applyPkt(dup_ack2, "nf1", pktCnt)  # the second DUP ACK from port 1 to port 0
pktCnt += 1

dup_ack3 = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="A", ack=curr_seq)
)
dup_ack3 = pad_pkt(dup_ack3, PKT_SIZE)
applyPkt(
    dup_ack3, "nf1", pktCnt
)  # the third DUP ACK from port 1 to port 0 -- fast retransmit
pktCnt += 1

no_action = compute_tuser(0, 0, 0, 0)
expPkt(
    dup_ack1, "nf0", drop=False, flow_id=flow_id, tuser=no_action
)  # the first DUP ACK from port 1 to port 0
expPkt(
    dup_ack2, "nf0", drop=False, flow_id=flow_id, tuser=no_action
)  # the second DUP ACK from port 1 to port 0

# the third DUP ACK from port 1 to port 0 -- fast retransmit: packet sent back to host with ACK flag set to 0.
dup_ack3 = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="", chksum=31361, ack=curr_seq)
)
dup_ack3 = pad_pkt(dup_ack3, PKT_SIZE)
retransmit = compute_tuser(
    1, 0, tuser_map["nf1"], 0
)  # CACHE_READ the cached packet from port 1
expPkt(dup_ack3, "nf0", drop=False, flow_id=flow_id, tuser=retransmit)


############################################################################################################################

# Test #4: Behaviour of the program when a fourth DUP ACK is received.
# Goal: After the program has retransmitted the required packet, if it receives the same DUP ACK (for the fourth time), it
#   will send this packet to host as it is. This is because the problem might be due to factors other than the loss of packets
#   at the receiver.
# Description:
#   - Send the 4th DUP ACK packet from from port 1 to port 0
#   - Expect the packet to be sent to host as it is, without any modification.

dup_ack4 = (
    Ether(src=MAC2, dst=MAC1)
    / IP(src=IP1_dst, dst=IP1_src)
    / TCP(sport=dport, dport=sport, flags="A", ack=curr_seq)
)
dup_ack4 = pad_pkt(dup_ack4, PKT_SIZE)
applyPkt(
    dup_ack4, "nf1", pktCnt
)  # the fourth DUP ACK from port 1 to port 0 -- send back to host
pktCnt += 1
back_to_host = compute_tuser(0, 0, 0, 0)  # send this packet to the sender as it is.
expPkt(dup_ack4, "nf0", drop=False, flow_id=flow_id, tuser=back_to_host)


############################################################################################################################

# Test #5: Behaviour of the program when there are multiple flows.
# Goal: When there are multiple flows, the program only process those packets with the flow matches the specific flow_id(s)
# that we are interested in, and have specified with our `retransmit` table in `commands.txt`.
# # Description:
#   - Create 3 flows and randomly interleave the flows' packets
#   - Expect to see that the program will process the other two flows as per normal, while assisting the fast retransmit
#   process of our flow of interest.

# Create 3 flows and mix them together
flow1 = make_flow(IP1_src, IP1_dst, sport, dport, 192)  # 3 + 2
flow2 = make_flow(IP2_src, IP2_dst, sport, dport, 320)  # 5 + 2
flow3 = make_flow(IP3_src, IP3_dst, sport, dport, 320)  # 5 + 2
trace = mix_flows([flow1, flow2, flow3])
# trace = mix_flows([flow2, flow3])
# trace = mix_flows([flow1])

# apply the trace
for pkt in trace:
    applyPkt(pkt, "nf0", pktCnt)
    pktCnt += 1
#
    flow_id = compute_tuple(pkt[IP].src, pkt[IP].dst, 6, pkt[TCP].sport, pkt[TCP].dport)
    action=0
    if (flow_id == 792281630049477301766976897099):
        action = compute_tuser(0,0,0,tuser_map["nf1"])
    else:
        action = compute_tuser(0,0,0,0)

    expPkt(pkt, "nf1", drop=False, flow_id=flow_id, tuser=action)

write_pcap_files()
