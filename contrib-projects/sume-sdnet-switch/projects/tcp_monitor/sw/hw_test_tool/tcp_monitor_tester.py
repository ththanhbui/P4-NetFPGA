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


"""
This is a tool to allow interactive testing of the tcp monitor tool
"""

import os, sys, re, cmd, subprocess, shlex, time
from threading import Thread
import random, socket, struct
import numpy as np

from nf_sim_tools import *

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/CLI/'))
import p4_regs_api

IFACE = "eth1"

PKT_SIZE = 1000 # default payload size (in bytes) 
MIN_PKT_SIZE = 64 
HEADER_SIZE = 54 # size of Ether/IP/TCP headers
MAC1 = "08:ba:5e:ba:11:08"
MAC2 = "08:ca:fe:be:ef:08"

NUM_BINS = 8

class TcpMonitorTester(cmd.Cmd):
    """A HW testing tool for the tcp_monitor design"""

    prompt = "testing> "
    intro = "The HW testing tool for the tcp_monitor design\n type help to see all commands"

    def _get_rand_IP(self):
        return socket.inet_ntoa(struct.pack('>I', random.randint(1, 0xffffffff)))

    def _get_rand_port(self):
        return random.randint(1, 0xffff)

    def _make_flow(self, flow_size):
        pkts = []
        srcIP = self._get_rand_IP()
        dstIP = self._get_rand_IP()
        sport = self._get_rand_port()
        dport = self._get_rand_port()
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

    """
    Generate a trace of flows indicated by the given parameters and apply to the switch 
    """
    def _run_flows(self, num_flows, min_size, max_size):
        trace = []
        for fid in range(num_flows):
            size = random.randint(min_size, max_size)
            # create the flows pkts
            flow_pkts = self._make_flow(size)
            # randomly interleave flow's pkts into trace
            trace = map(next, random.sample([iter(trace)]*len(trace) + [iter(flow_pkts)]*len(flow_pkts), len(trace)+len(flow_pkts)))        

        # apply trace to the switch
        sendp(trace, iface=IFACE)

    def _clear_dist(self):
        for i in range(NUM_BINS):
            p4_regs_api.reg_write('dist', i, 0)


    def _parse_line(self, line):
        args = line.split()
        if (len(args) != 3):
            print >> sys.stderr, "ERROR: usage..."
            self.help_run_flows()
            return (None, None, None)
        try:
            num_flows = int(args[0])
            min_size = int(args[1])
            max_size = int(args[2])
        except:
            print >> sys.stderr, "ERROR: all arguments must be valid integers"
            return (None, None, None)

        return (num_flows, min_size, max_size)

    def do_run_flows(self, line):
        (num_flows, min_size, max_size) = self._parse_line(line) 
        if (num_flows is not None and min_size is not None and max_size is not None):
            self._run_flows(num_flows, min_size, max_size)

    def help_run_flows(self):
        print """
run_flows <num_flows> <min_size> <max_size> 
DESCRIPTION: Create a trace simulating some number of distinct TCP flows all running simultaneously
and apply the resulting packets to the switch. The size (in bytes) of each flow will be randomly 
chosen between <min_size> and <max_size> 
    <num_flows> : the number of concurrent active flows to run through the switch
    <min_size>  : the minimum possible size of each flow
    <max_size>  : the maximum possible size of each flow
"""

    def _get_size(self, dist):
        if dist == 'uniform':
            return random.randint(0, 128000)
        if dist == 'normal':
            return int(random.gauss(64000,32000))

    def do_make_dist(self, line):
        self._clear_dist()
        try:
            while True:
                self.run_batch(line)
        except KeyboardInterrupt:
            return

    def complete_make_dist(self, text, line, begidx, endidx):
        dists = ['normal', 'uniform']
        if not text:
            completions = dists
        else:
            completions = [ r for r in dists if r.startswith(text)]
        return completions

    def help_make_dist(self):
        print """
make_dist <type>
DESCRIPTION: sample flow sizes from the specified distribution and send flows in batches of 20.
    Supported types are:
        uniform
        normal 

"""

    def run_batch(self, dist):
        trace = []
        for i in range(20):
            flow_size = self._get_size(dist)
            if flow_size is not None:
                trace += self._make_flow(flow_size)
        sendp(trace, iface=IFACE)

    def do_clear_dist(self, line):
        self._clear_dist()


    def help_clear_dist(self):
        print """
clear_dist
DESCRIPTION: clear the distribution 

"""

    def do_EOF(self, line):
        print ""
        return True

if __name__ == '__main__':
    if len(sys.argv) > 1:
        TcpMonitorTester().onecmd(' '.join(sys.argv[1:]))
    else:
        TcpMonitorTester().cmdloop()
