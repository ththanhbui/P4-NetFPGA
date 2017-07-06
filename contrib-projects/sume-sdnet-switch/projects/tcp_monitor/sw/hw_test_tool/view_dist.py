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
Tool to view the flow size distribution as calculated by the
tcp_monitor P4 program running on the switch
"""

import argparse, os, sys
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sched, time, copy

from ascii_graph import Pyasciigraph

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/CLI/'))
import p4_regs_api


SAMP_INTERVAL = 1 # seconds
NUM_BINS = 8
dist_labels = ('0-16K', '16K-32K', '32K-48K', '48K-64K', '64K-80K', '80K-96K', '96K-112K', '>112K')
dist_vals = [0, 0, 0, 0, 0, 0, 0, 0]

SAMP_INT_HIST = 100 # milliseconds

barcollection = None
fig = None
ax = None

def barlist(): 
    data = []
    for i in range(NUM_BINS):
         data.append(p4_regs_api.reg_read('dist', i))
    return data 


def animate(i):
    global barcollection, fig, ax
    y=barlist()
    for i, b in enumerate(barcollection):
        b.set_height(y[i])

    plt.ylim([0, max(y)*1.2])

def run_gui_plot():
    global barcollection, fig, ax
    fig, ax = plt.subplots()

    plt.title('Flow Size Distribution', fontweight='bold', fontsize=22)
    plt.ylabel('Number of Flows', fontweight='bold', fontsize=20)
    plt.xlabel('Flow Size (bytes)', fontweight='bold', fontsize=20)
    x_pos = range(len(dist_labels))
    plt.xticks(x_pos, dist_labels)
    ax.tick_params(labelsize=14)

    barcollection = plt.bar(x_pos, barlist(), align='center', alpha=0.5)
    anim=animation.FuncAnimation(fig,animate,repeat=True,blit=False, interval=SAMP_INT_HIST)

    plt.show()


####### ASCII Distrbution #######

def print_dist():
    global dist_labels, dist_vals
    graph = Pyasciigraph()
    flow_dist = zip(dist_labels, dist_vals)
    for line in  graph.graph('Flow Size Distribution', flow_dist):
        print(line)


def update_dist(sc):
    global dist_vals
    new_dist = copy.deepcopy(dist_vals)
    for i in range(NUM_BINS):
        new_dist[i] = p4_regs_api.reg_read('dist', i)
    if new_dist != dist_vals:
        dist_vals = new_dist
        print_dist()
    sc.enter(SAMP_INTERVAL, 1, update_dist, (sc,))

"""
Creates and updates ascii plot of the distribution computed by the switch
"""
def run_ascii_plot():
    print_dist()
    s = sched.scheduler(time.time, time.sleep)
    s.enter(SAMP_INTERVAL, 1, update_dist, (s,))
    s.run()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gui', action='store_true', default=False, help="Display the distribution via GUI rather than on the command line")
    args = parser.parse_args()  

    if args.gui:
#        fig, ax = plt.subplots()
#        p = Plotter(fig, ax)
#        ani = animation.FuncAnimation(fig, p.run, p.data_gen, blit=False, interval=SAMP_INT_HIST,
#                                  repeat=False) #, init_func=p.init)
#        plt.show()

        run_gui_plot()

    else:
        run_ascii_plot()

if __name__ == "__main__":
    main()
