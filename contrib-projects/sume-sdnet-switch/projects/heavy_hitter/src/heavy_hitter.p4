//
// Copyright (c) 2019 Stephen Ibanez
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

/*
 * A basic heavy hitter detection program.
 */

#include <core.p4>
#include "sume_event_switch.p4"

#define L2_NUM_FLOWS 4

typedef bit<48> EthAddr_t;
typedef bit<32> IPv4Addr_t;
typedef bit<L2_NUM_FLOWS> FlowId_t;
typedef bit<8> ByteCnt_t;

const bit<16> IPV4_TYPE = 0x0800;
const bit<16> LOG_TYPE  = 0x2121;

const ByteCnt_t CREDIT     = 10;
const ByteCnt_t HH_THRESH  = 100;

const port_t LOG_PORT = 0b01000000;

#define REG_READ        8w0
#define REG_WRITE       8w1
#define REG_ADD         8w2
#define REG_SUB         8w3
#define REG_NULL        8w4
#define REG_READ_WRITE  8w5
#define REG_ADD_SAT     8w6
#define REG_SUB_SAT     8w7

/* period register:
 *   - the period at which timer events fire
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(1)
extern void period_reg_rw(in bit<1> index,
                          in bit<32> newVal,
                          in bit<8> opCode,
                          out bit<32> result);

/* timerFid register:
 *   - Track the flowID to sample with the timer events
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(1)
extern void timerFid_reg_raw(in bit<1> index,
                             in FlowId_t newVal,
                             in FlowId_t incVal,
                             in bit<8> opCode,
                             out FlowId_t result);

/* localSum register:
 *   - Track the recent byte count
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(L2_NUM_FLOWS)
extern void flowBytes_reg_multi_raws(in FlowId_t index_0,
                                     in ByteCnt_t data_0,
                                     in bit<8> opCode_0,
                                     in FlowId_t index_1,
                                     in ByteCnt_t data_1,
                                     in bit<8> opCode_1,
                                     in FlowId_t index_2,
                                     in ByteCnt_t data_2,
                                     in bit<8> opCode_2,
                                     out ByteCnt_t result);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void now_timestamp(in bit<1> valid, out bit<64> result);

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

header Log_h {
    bit<64> tstamp;
}

// List of all recognized headers
struct Parsed_packet { 
    Ethernet_h ethernet; 
    IPv4_h ip;
    Log_h log;
}

// user defined metadata: can be used to shared information between
// TopParser, TopPipe, and TopDeparser 
struct user_metadata_t {
    bit<8>  unused;
}

// digest data is unused in this architecture
struct digest_data_t {
    bit<8>  unused;
}

// Parser Implementation
@Xilinx_MaxPacketRegion(16384)
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
            LOG_TYPE: parse_log;
            default: accept;
        }
    }

    state parse_ipv4 {
        b.extract(p.ip);
        transition accept;
    }

    state parse_log {
        b.extract(p.log);
        transition accept;
    }

}

// match-action pipeline
control TopPipe(inout Parsed_packet p,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    FlowId_t pkt_flowID;

    action set_dst_port(port_t port) {
        sume_metadata.dst_port = port;
    }

    table ipv4_forward {
        key = { p.ip.dstAddr : exact; }
        actions = {
            set_dst_port;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    action set_pkt_flowID(FlowId_t ID) {
        pkt_flowID = ID;
    }

    table lookup_pkt_flowID {
        key = { p.ip.srcAddr : exact; }
        actions = {
            set_pkt_flowID;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    apply {
        // configure the period of the timer events
        period_reg_rw(0, 0, REG_READ, sume_metadata.timer_period);

        pkt_flowID = 0; // default

        if (p.ip.isValid()) {
            // set destination port and flowID
            ipv4_forward.apply();
            lookup_pkt_flowID.apply();
        }
        else if (p.log.isValid()) {
            sume_metadata.dst_port = LOG_PORT;
            now_timestamp(1, p.log.tstamp);
        }

        // default values
        FlowId_t timer_flowID = 0;
        FlowId_t index_0 = 0; ByteCnt_t data_0 = 0; bit<8> opCode_0 = REG_NULL;
        FlowId_t index_1 = 0; ByteCnt_t data_1 = 0; bit<8> opCode_1 = REG_NULL;
        FlowId_t index_2 = 0; ByteCnt_t data_2 = 0; bit<8> opCode_2 = REG_NULL;
        // compute the sum of bytes over a recent amount of time
        if (p.ip.isValid()) {
            index_0 = pkt_flowID;
            data_0 = (ByteCnt_t) sume_metadata.pkt_len;
            opCode_0 = REG_ADD_SAT; // saturating addition
        }
        if (sume_metadata.timer_trigger == 1) {
            // alternate between flows
            timerFid_reg_raw(0, 0, 1, REG_ADD, timer_flowID);
            index_1 = timer_flowID;
            data_1 = CREDIT;
            opCode_1 = REG_SUB_SAT; // saturating subtraction
        }

        // update flowBytes register
        ByteCnt_t flowBytes;
        flowBytes_reg_multi_raws(index_0, data_0, opCode_0,
                                 index_1, data_1, opCode_1,
                                 index_2, data_2, opCode_2,
                                 flowBytes);

        if (p.ip.isValid() && (flowBytes > HH_THRESH) ) {
            // heavy hitter!
            sume_metadata.gen_packet = 1;
        }

    }
}

// Deparser Implementation
@Xilinx_MaxPacketRegion(16384)
control TopDeparser(packet_out b,
                    in Parsed_packet p,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 
    apply {
        b.emit(p.ethernet); 
        b.emit(p.ip); 
        b.emit(p.log);
    }
}

// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
