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


import os, sys, re, cmd, subprocess, shlex, time
from threading import Thread

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from int_headers import *
from nf_sim_tools import *

IFACE = "eth2"
PKT_SIZE = 64
MAX_HOP = 10

os.system('sudo ifconfig {0} 10.0.0.11 netmask 255.255.255.0'.format(IFACE))

def get_pkt_layers(pkt):
    layers = []
    counter = 0
    while True:
        layer = pkt.getlayer(counter)
        if (layer != None):
            layers.append((type(layer), layer))
        else:
            break
        counter += 1
    return layers

def print_INT_data(pkt):
    count = 0
    data_names = []
    bitmask_str = '{0:05b}'.format(pkt[INT].instruction_bitmask)
    for c in bitmask_str:
        count += 1
        if c == '1':
            if count == 1:
                data_names.append('SWITCH_ID')
            elif count == 2:
                data_names.append('INGRESS_PORT')
            elif count == 3:
                data_names.append('Q_OCCUPANCY')
            elif count == 4:
                data_names.append('INGRESS_TIMESTAMP')
            elif count == 5:
                data_names.append('EGRESS_PORT')

    int_data_fmat_string = "             | {0:<{width}} bos:{1:<{width}} data:{2:<{width}} "
    layers = get_pkt_layers(pkt)
    data_layers = [l[1] for l in layers if l[0] == INT_data]
    if len(data_names) != len(data_layers):
        print "ERROR: mismatch between number of expected and received INT data layers"
    for (name, layer) in zip(data_names, data_layers):
        bos = layer.bos
        if name in ['INGRESS_PORT', 'EGRESS_PORT']:
            data = '{0:08b}'.format(layer.data)
        elif name == 'Q_OCCUPANCY':
            data = hex(layer.data)
        else:
            data = str(layer.data)
        print int_data_fmat_string.format(name, bos, data, width=20)


def print_INT(pkt):
    if INT in pkt:
        if pkt[INT].total_hop_cnt > 0:
            width = 10
            n = 9
            int_fmat_string =      "|  ETHERNET  | ins_cnt:{0:<{width}} max_hop:{1:<{width}} total_hop:{2:<{width}} bitmask:{3:<{width}} |"
            print "Recieved pkt: "
            print "{0:-<{width}}".format("-", width=n*width)
            print int_fmat_string.format(pkt[INT].ins_cnt, pkt[INT].max_hop_cnt, pkt[INT].total_hop_cnt, '0b'+'{0:05b}'.format(pkt[INT].instruction_bitmask), width=width)
            print_INT_data(pkt)
            print "{0:-<{width}}\n".format("-", width=n*width)


def main():
    sniff(iface=IFACE, prn=print_INT, count=0)


if __name__ == "__main__":
    main()

