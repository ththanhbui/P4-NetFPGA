
import matplotlib
import matplotlib.pyplot as plt

import sys, os

QSIZE = 2**18

class QueueStats(object):
    def __init__(self, log_pkt_list, start_time):
        """
        log_pkt_list: log_pkt_list: a list of LogPkts which have attributes: qsize (B) and time (ns)
        """
        self.start_time = start_time
        # convert packet list into per-flow qsize measurements and times
        self.times = {}
        self.qsizes = {}
        self.parse_pkt_list(log_pkt_list)

    def parse_pkt_list(self, log_pkt_list):
        try:
            assert(len(log_pkt_list) != 0)
        except AssertionError as e:
            print >> sys.stderr, "ERROR: QueueStats.parse_pkt_list: len(log_pkt_list) = 0"
            sys.exit(1)

        for pkt in log_pkt_list:
            # add time sample
            time = (pkt.time-self.start_time)*1e-6 # convert to ms
            qsize = pkt.qsize
            if pkt.flowID not in self.times:
                self.times[pkt.flowID] = [time]
            else:
                self.times[pkt.flowID].append(time)
            # add qsize sample
            if pkt.flowID not in self.qsizes:
                self.qsizes[pkt.flowID] = [qsize]
            else:
                self.qsizes[pkt.flowID].append(qsize)

    def line_gen(self):
        lines = ['-', '--', ':', '-.']
        colors = ['b', 'g', 'r', 'm']
        i = 0
        while True:
            yield lines[i], colors[i]
            i += 1
            i = i % len(lines)
    
    def plot_queues(self):
        line_generator = self.line_gen()
        plt.figure()
        for flowID in self.qsizes.keys():
            linestyle, color = line_generator.next()
            plt.plot(self.times[flowID], self.qsizes[flowID], linewidth=5, label='Flow {}'.format(flowID), linestyle=linestyle, marker='o')
        plt.axhline(y=QSIZE, color='r', linestyle=':', linewidth=3)
        plt.xlabel('Time (ms)')
        plt.ylabel('Queue Occupancy (B)')
        plt.legend(loc='upper left')

