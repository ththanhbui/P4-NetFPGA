//
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


#include <core.p4>
#include <sume_switch.p4>

/*
 * tcp_monitor.p4
 * 
 * Description:
 * This switch design tracks the number of packets sent on each TCP connection
 * in each direction and creates a histogram representing the flow size
 * ditribution.
 */

typedef bit<48> EthAddr_t; 
typedef bit<32> IPv4Addr_t;

#define IPV4_TYPE 0x0800
#define TCP_TYPE 6

#define SYN_MASK 8w0b0000_0010
#define SYN_POS 1

#define FIN_MASK 8w0b0000_0001
#define FIN_POS 0


// define histogram bin boundaries
#define LEVEL_1   16000
#define LEVEL_2   32000
#define LEVEL_3   48000
#define LEVEL_4   64000
#define LEVEL_5   80000
#define LEVEL_6   96000
#define LEVEL_7   112000 

#define REG_READ   8w0
#define REG_WRITE  8w1
#define REG_ADD    8w2


#define HASH_WIDTH 5
// hash function
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void hash_lrc(in bit<104> in_data, out bit<HASH_WIDTH> result);

// byte_cnt register
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void byte_cnt_reg_raw(in bit<HASH_WIDTH> index,
                             in bit<32> newVal,
                             in bit<32> incVal,
                             in bit<8> opCode,
                             out bit<32> result);

// dist register
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(3)
extern void dist_reg_raw(in bit<3> index,
                         in bit<32> newVal,
                         in bit<32> incVal,
                         in bit<8> opCode,
                         out bit<32> result);


// standard Ethernet header
header Ethernet_h { 
    EthAddr_t dstAddr; 
    EthAddr_t srcAddr; 
    bit<16> etherType;
}

// IPv4 header without options
header IPv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> tos; 
    bit<16> totalLen; 
    bit<16> identification; 
    bit<3> flags;
    bit<13> fragOffset; 
    bit<8> ttl;
    bit<8> protocol; 
    bit<16> hdrChecksum; 
    IPv4Addr_t srcAddr; 
    IPv4Addr_t dstAddr;
}

// TCP header without options
header TCP_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4> dataOffset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

// List of all recognized headers
struct Parsed_packet { 
    Ethernet_h ethernet; 
    IPv4_h ip;
    TCP_h tcp;
}

// user defined metadata: can be used to share information between
// TopParser, TopPipe, and TopDeparser 
struct user_metadata_t {
    bit<8>  unused;
}

// digest data to send to cpu if desired. MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}

// Parser Implementation
@Xilinx_MaxPacketRegion(8192)
parser TopParser(packet_in b, 
                 out Parsed_packet p, 
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {
    state start {
        b.extract(p.ethernet);
        user_metadata.unused = 0;
        digest_data.unused = 0;
        transition select(p.ethernet.etherType) {
            IPV4_TYPE: parse_ipv4;
            default: reject;
        } 
    }

    state parse_ipv4 {
        b.extract(p.ip);
        transition select(p.ip.protocol) {
            TCP_TYPE: parse_tcp;
            default: reject;
        }
    }

    state parse_tcp {
        b.extract(p.tcp);
        transition accept;
    }
}

// match-action pipeline
control TopPipe(inout Parsed_packet p,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    action set_output_port(port_t port) {
        sume_metadata.dst_port = port;
    }

    table forward {
        key = { p.ethernet.dstAddr: exact; }

        actions = {
            set_output_port;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    apply {
        if (!forward.apply().hit) {
            sume_metadata.drop = 1;
        }

        if (p.tcp.isValid()) { 

            // metadata for byte_cnt register access
            bit<HASH_WIDTH> hash_result;
            bit<32> newVal;
            bit<32> incVal;
            bit<8> opCode;

            // compute hash of 5-tuple to obtain index for byte_cnt register
            hash_lrc(p.ip.srcAddr++p.ip.dstAddr++p.ip.protocol++p.tcp.srcPort++p.tcp.dstPort, hash_result); 
            
            // TODO: set newVal, incVal, and opCode appropriately based on
            // whether this is a SYN packet 
            if ((p.tcp.flags & SYN_MASK) >> SYN_POS == 1) {
                // Is a SYN packet
                newVal = 0; // reset the pkt_cnt state for this entry
                incVal = 0; // unused
                opCode = REG_WRITE;
            } else {
                // Is not a SYN packet
                newVal = 0; // unused
                incVal = 16w0++sume_metadata.pkt_len - 32w54; // count TCP payload bytes for this connection
                opCode = REG_ADD;
            }
           
            // access the byte_cnt register 
            bit<32> numBytes;
            byte_cnt_reg_raw(hash_result, newVal, incVal, opCode, numBytes);

            bit<3> index;

            // TODO: set index, newVal, incVal, and opCode appropriately
            // based on whether or not this is a FIN packet
            if((p.tcp.flags & FIN_MASK) >> FIN_POS == 1) {
                // FIN bit is set 
                newVal = 0; // unused
                incVal = 1; // increment one of the buckets
                opCode = REG_ADD;
  
                if (numBytes <= LEVEL_1) {
                    index = 0;
                } else if (LEVEL_1 < numBytes && numBytes <= LEVEL_2) {
                    index = 1;
                } else if (LEVEL_2 < numBytes && numBytes <= LEVEL_3) {
                    index = 2;
                } else if (LEVEL_3 < numBytes && numBytes <= LEVEL_4) {
                    index = 3;
                } else if (LEVEL_4 < numBytes && numBytes <= LEVEL_5) {
                    index = 4;
                } else if (LEVEL_5 < numBytes && numBytes <= LEVEL_6) {
                    index = 5;
                } else if (LEVEL_6 < numBytes && numBytes <= LEVEL_7) {
                    index = 6; 
                } else {
                    index = 7;
                }
            }
            else {
                index = 0;
                newVal = 0; // unused
                incVal = 0; // unused
                opCode = REG_READ;
            }
 
            // access the distribution register 
            bit<32> result; 
            dist_reg_raw(index, newVal, incVal, opCode, result);

        }

    }
}

// Deparser Implementation
@Xilinx_MaxPacketRegion(8192)
control TopDeparser(packet_out b,
                    in Parsed_packet p,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 
    apply {
        b.emit(p.ethernet); 
        b.emit(p.ip);
        b.emit(p.tcp);
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;

