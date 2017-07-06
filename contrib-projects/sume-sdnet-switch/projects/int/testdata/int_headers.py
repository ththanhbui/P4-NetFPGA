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


from scapy.all import *
import sys, os

INT_TYPE = 0x1213

SWITCH_ID_MASK =  0b10000
SWITCH_ID_POS = 4
INGRESS_PORT_ID_MASK = 0b01000
INGRESS_PORT_ID_POS =  3
Q_OCCUPANCY_MASK = 0b00100
Q_OCCUPANCY_POS =  2
INGRESS_TSTAMP_MASK = 0b00010
INGRESS_TSTAMP_POS = 1
EGRESS_PORT_ID_MASK = 0b00001
EGRESS_PORT_ID_POS = 0

class INT(Packet):
    name = "INT"
    fields_desc = [
        BitField("ver", 0, 2),
        BitField("rep", 0, 2),
        BitField("c", 0, 1),
        BitField("e", 0, 1),
        BitField("rsvd1", 0, 5),
        BitField("ins_cnt", 0, 5),
        BitField("max_hop_cnt", 0, 8),
        BitField("total_hop_cnt", 0, 8),
        BitField("instruction_bitmask", 0, 5),
        BitField("rsvd2", 0, 27)
    ]

class INT_data(Packet):
    name = "INT_data"
    fields_desc = [
        BitField("bos", 0, 1),
        BitField("data", 0, 31)
    ]    

bind_layers(Ether, INT, type=INT_TYPE)
bind_layers(INT, Raw, total_hop_cnt=0)
bind_layers(INT, INT_data)
bind_layers(INT_data, INT_data, bos=0)
bind_layers(INT_data, Raw, bos=1)

