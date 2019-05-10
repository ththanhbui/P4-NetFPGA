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
 * A simplified version of the FRED AQM algorithm used for the 2019 P4 Workshop demo.
 *
 * High-level description:
 *   - Track per-flow queue occupancy using enq and deq events
 *   - Drop packet when queue occupancy exceeds some threshold value
 *   - Generate periodic log packets to report queue occupancy to monitor
 *
 * NOTE: this switch forwards based on dst IP but doesn't handle ARP so the hosts
 * machines must be preconfigured. For example:
 * # arp -i eth1 -s 10.0.0.1 08:00:00:00:00:01
 */


#include <core.p4>
#include "sume_event_switch.p4"

typedef bit<48> EthAddr_t; 
typedef bit<32> IPv4Addr_t;

typedef bit<8> FlowID_t;
typedef bit<32> Qsize_t;

const bit<16> IPV4_TYPE = 0x0800;
const bit<16> LOG_TYPE  = 0x2121;
const bit<16> NULL_TYPE = 0x0000;

const port_t LOG_PORT = 0b01000000;

#define REG_READ   8w0
#define REG_WRITE  8w1
#define REG_ADD    8w2
#define REG_SUB    8w3
#define REG_NULL   8w4
// operation to perform write but return the
// old value in the register rather than the
// new value
// used for the lastSample extern
#define REG_READ_WRITE  8w5

/* period register:
 *   - the period at which timer events fire
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(1)
extern void period_reg_rw(in bit<1> index,
                          in bit<32> newVal,
                          in bit<8> opCode,
                          out bit<32> result);

/* lastFlowID register:
 *   - Remember the last flowID that was queried
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(1)
extern void lastFlowID_reg_raw(in bit<1> index,
                               in bit<1> newVal,
                               in bit<1> incVal,
                               in bit<8> opCode,
                               out bit<1> result);

/* lastSample register:
 *   - the last qsize sample per flow
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(8)
extern void lastSample_reg_rw(in FlowID_t index,
                              in bit<32> newVal,
                              in bit<8> opCode,
                              out bit<32> result);

/* qsize register:
 *   - Track the per-flow queue occupancy using enqueue and dequeue events
 */
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(8)
extern void qsize_reg_multi_raws(in FlowID_t index_0,
                                 in Qsize_t data_0,
                                 in bit<8> opCode_0,
                                 in FlowID_t index_1,
                                 in Qsize_t data_1,
                                 in bit<8> opCode_1,
                                 in FlowID_t index_2,
                                 in Qsize_t data_2,
                                 in bit<8> opCode_2,
                                 out Qsize_t result);

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

// header to log queue size
header Log_h {
    FlowID_t flowID;
    Qsize_t qsize;
    bit<64> time;
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

// digest data is unused
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

    // metadata used for IP and Log packets
    FlowID_t pkt_flowID;
    // Buffer occupancy threshold at which to drop packets
    Qsize_t fred_thresh;

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

    action set_pkt_flowID(FlowID_t ID) {
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

    action set_fred_thresh(Qsize_t thresh) {
        fred_thresh = thresh;
    }

    table lookup_thresh {
        key = { pkt_flowID : exact; }
        actions = {
            set_fred_thresh;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    /* Event types to handle:
     *   - IPv4 packets => query qsize
     *   - Log packets => query qsize
     *   - Timer events => generate log packets
     *   - Enqueue events => increment qsize
     *   - Dequeue events => decrement qsize
     *   - Link status events => nothing
     */
    apply {
        pkt_flowID = 0; // default initialization
        fred_thresh = 0; // default initialization

        // configure the period of the timer events
        period_reg_rw(0, 0, REG_READ, sume_metadata.timer_period);
        // generate log packets
        if (sume_metadata.timer_trigger == 1) {
            sume_metadata.gen_packet = 1;
        }

        // set destination port and pkt_flowID
        if (p.ip.isValid()) {
            ipv4_forward.apply();
            lookup_pkt_flowID.apply();
        }
        else if (p.log.isValid()) {
            sume_metadata.dst_port = LOG_PORT;
            // alternate between flowID 0 and 1
            bit<1> fid;
            lastFlowID_reg_raw(0, 0, 1, REG_ADD, fid);
            pkt_flowID = (FlowID_t)fid;
        }

        // access per-flow queue size state
        FlowID_t index_0; FlowID_t index_1; FlowID_t index_2;
        Qsize_t data_0; Qsize_t data_1; Qsize_t data_2;
        bit<8> opCode_0; bit<8> opCode_1; bit<8> opCode_2;
        if ( p.ip.isValid() || p.log.isValid()) {
            // query specified qsize
            index_0 = pkt_flowID;
            data_0 = 0; // unused
            opCode_0 = REG_READ;
        }
        else {
            index_0 = 0; // unused
            data_0  = 0; // unused
            opCode_0 = REG_NULL;
        }

        // increment qsize using enqueue events
        if ( sume_metadata.enq_trigger == 1 ) {
            index_1 = sume_metadata.enq_flowID;
            data_1 = (Qsize_t)sume_metadata.enq_pkt_len;
            opCode_1 = REG_ADD;
        }
        else {
            index_1 = 0; // unused
            data_1  = 0; // unused
            opCode_1 = REG_NULL;
        }

        // decrement qsize using dequeue events
        if ( sume_metadata.deq_trigger == 1 ) {
            index_2 = sume_metadata.deq_flowID;
            data_2  = (Qsize_t)sume_metadata.deq_pkt_len;
            opCode_2 = REG_SUB;
        }
        else {
            index_2 = 0; // unused
            data_2  = 0; // unused
            opCode_2 = REG_NULL;
        }

        // Access the qsize register
        Qsize_t qsize;
        qsize_reg_multi_raws(index_0,
                             data_0,
                             opCode_0,
                             index_1,
                             data_1,
                             opCode_1,
                             index_2,
                             data_2,
                             opCode_2,
                             qsize);
        // qsize is now the result of performing the operation specified by:
        // index_0, data_0, and opCode_0

        // implement AQM policy using qsize
        if (p.ip.isValid()) {
            // only apply the threshold to flows that actually have a
            // threshold assigned to them
            if (lookup_thresh.apply().hit) {
                if (qsize > fred_thresh) {
                    // drop packet
                    sume_metadata.dst_port = 0;
                }
            }
        }

        // set log header fields
        if (p.log.isValid()) {
            p.log.flowID = pkt_flowID;
            p.log.qsize = qsize;
            now_timestamp(1, p.log.time);
            Qsize_t prev_qsize;
            // record this qsize sample
            lastSample_reg_rw(pkt_flowID, qsize, REG_READ_WRITE, prev_qsize);
            if (qsize == prev_qsize) {
                // only transmit log packets that contain new samples
                sume_metadata.dst_port = 0;
            }
        }

        // overwrite user enq and deq metadata
        // this data will be recirculated when enq/deq events fire for this packet
        if (p.ip.isValid()) {
            sume_metadata.enq_flowID = pkt_flowID;
            sume_metadata.enq_pkt_len = sume_metadata.pkt_len;
            sume_metadata.deq_flowID = pkt_flowID;
            sume_metadata.deq_pkt_len = sume_metadata.pkt_len;
        }
        else {
            // default user enq/deq metadata
            sume_metadata.enq_flowID = 0;
            sume_metadata.enq_pkt_len = 0;
            sume_metadata.deq_flowID = 0;
            sume_metadata.deq_pkt_len = 0;
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
