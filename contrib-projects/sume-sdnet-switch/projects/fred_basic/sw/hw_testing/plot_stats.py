#!/usr/bin/env python

import sys, os
import matplotlib
import matplotlib.pyplot as plt
import argparse

from demo_utils.scapy_patch import rdpcap_raw

from demo_utils.log_pkt_parser import LogPktParser
from demo_utils.queue_stats import QueueStats

def plot_stats(input_log_pkts):
    start_time = input_log_pkts[0].time

    print 'Creating Plots ...'

    # plot queue sizes
    queue_stats = QueueStats(input_log_pkts, start_time)
    queue_stats.plot_queues()
    plt.title('Per-Flow Queue Occupancy')

def parse_log_pkts(pcap_file):
    try:
        log_pkts = []
        for (pkt, _) in rdpcap_raw(pcap_file):
            if pkt is not None:
                log_pkts.append(pkt)
    except IOError as e:
        print >> sys.stderr, "ERROR: failed to read pcap file: {}".format(pcap_file)
        sys.exit(1)
    except:
        print >> sys.stderr, "ERROR: empty pcap file? {}".format(pcap_file)
        sys.exit(1)

    # Parse the logged pkts
    pkt_parser = LogPktParser()
    log_pkts = pkt_parser.parse_pkts(log_pkts)
    return log_pkts

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pcap', type=str, default='pcaps/log.pcap', help="the pcap trace to plot")
    args = parser.parse_args()

    # parse the logged pcap files
    input_log_pkts = parse_log_pkts(args.pcap)

    # plot input / output rates
    plot_stats(input_log_pkts)

    font = {'family' : 'normal',
            'weight' : 'bold',
            'size'   : 32}
    matplotlib.rc('font', **font)
    plt.show()
    

if __name__ == '__main__':
    main()

