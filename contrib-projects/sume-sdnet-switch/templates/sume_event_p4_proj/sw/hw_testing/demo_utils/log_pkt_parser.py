
import sys, os 
import struct, socket

"""
File: log_pkt_parser.py

Description: Parses the logged pkts

"""

LOG_TYPE = 0x2121

class LogPkt():
    def __init__(self, flowID, qsize, time):
        self.flowID = flowID
        self.qsize = qsize
        self.time = time*5 # convert to ns

    def __str__(self):
        return 'flowID = {0: <4}, qsize = {1: <6}, time = {2: <6}'.format(self.flowID, self.qsize, self.time)

class LogPktParser(object):

    def __init__(self):
        pass

    def parse_pkts(self, pkt_bufs):
        """
        Inputs:
            pkt_bufs - a list of raw pkt buffers
        """
        parsed_pkts = []
        for buf in pkt_bufs:
            pkt = self.parse_pkt(buf)
            if pkt is not None:
                parsed_pkts.append(pkt)
        parsed_pkts.sort(key=lambda x: x.time)
        return parsed_pkts

    def parse_pkt(self, pkt):
        try:
            etherType = struct.unpack(">H", pkt[12:14])[0]
            if etherType == LOG_TYPE:
                flowID = struct.unpack(">B", pkt[14])[0]
                qsize = struct.unpack(">I", pkt[15:19])[0]
                time = struct.unpack(">Q", pkt[19:27])[0]
                return LogPkt(flowID, qsize, time)
            else:
                return None
        except struct.error as e:
            print >> sys.stderr, "WARNING: could not unpack packet to obtain all fields, len(pkt) = {}".format(len(pkt))
            print e
            return None

