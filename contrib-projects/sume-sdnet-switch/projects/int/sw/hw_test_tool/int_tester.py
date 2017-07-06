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

IFACE = "eth1"

PKT_SIZE = 64
ETH_DST = "08:22:22:22:22:08"
ETH_SRC = "08:11:11:11:11:08"
MAX_HOP = 10

os.system('sudo ifconfig {0} 10.0.0.10 netmask 255.255.255.0'.format(IFACE))

TCPDUMP = subprocess.Popen(shlex.split("tcpdump -i {0} -w /dev/null".format(IFACE)))
time.sleep(0.1)

class IntTester(cmd.Cmd):
    """The HW testing tool for the INT design"""

    prompt = "testing> "
    intro = "The HW testing tool for the INT design\n type help to see all commands"

    def _to_int(self, line):
        try: 
            val = int(line, 0)
            assert(val >= 0 and val <= 2**5-1)
            return val
        except:
            print >> sys.stderr, "ERROR: bitmask must be valid positive integers that fits in 5 bits"
            return -1


    """
    Submit packet to the switch and print the results
    """
    def _submit_pkt(self, pkt):
        sendp(pkt, iface=IFACE)

        width = 10
        n = 9
        int_fmat_string =      "|  ETHERNET  | ins_cnt:{0:<{width}} max_hop:{1:<{width}} total_hop:{2:<{width}} bitmask:{3:<{width}} |"
        print "Sent pkt: "
        print "{0:-<{width}}".format("-", width=n*width)
        print int_fmat_string.format(pkt[INT].ins_cnt, pkt[INT].max_hop_cnt, pkt[INT].total_hop_cnt, '{0:05b}'.format(pkt[INT].instruction_bitmask), width=width)
        print "{0:-<{width}}\n".format("-", width=n*width)

    def _parse_line(self, line):
        args = line.split()
        if (len(args) != 1):
            print >> sys.stderr, "ERROR: usage..."
            self.help_run_test()
            return
        bitmask = self._to_int(args[0])
        if bitmask == -1:
            return None

        bitmask_str = bin(bitmask)
        ins_cnt = bitmask_str.count('1')

        pkt = Ether(dst=ETH_DST, src=ETH_SRC) / INT(ins_cnt=ins_cnt, max_hop_cnt=MAX_HOP, total_hop_cnt=0, instruction_bitmask=bitmask)
        pkt = pad_pkt(pkt, PKT_SIZE) # pad pkt to desired size
        return pkt

    def do_run_test(self, line):
        pkt = self._parse_line(line) 
        if pkt is not None:
            self._submit_pkt(pkt)

    def help_run_test(self):
        print """
run_test bitmask 
DESCRIPTION: send a packet with the INT header set that uses the provided bitmask 
NOTES:
    bitmask : which metadata to insert into packet.
              format - 0b<SWITCH_ID_BIT><INGRESS_PORT_BIT><Q_SIZE_BIT><INGRESS_TSTAMP_BIT><EGRESS_PORT_BIT>
              example: the following command will send an INT packet that requests the switchID, and
                       ingress/egress ports
                       testing> run_test 0b11001
"""

    def do_exit(self, line):
        if (TCPDUMP.poll() is None):
            TCPDUMP.terminate()
        sys.exit(0)

    def do_EOF(self, line):
        print ""
        if (TCPDUMP.poll() is None):
            TCPDUMP.terminate()
        return True

if __name__ == '__main__':
    if len(sys.argv) > 1:
        IntTester().onecmd(' '.join(sys.argv[1:]))
        if (TCPDUMP.poll() is None):
            TCPDUMP.terminate()
    else:
        IntTester().cmdloop()
