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

/* This program processes Ethernet packets,
 * performing forwarding based on the destination Ethernet Address
 */
typedef bit<48> EthernetAddress; 

#define INT_TYPE 0x1213

#define REG_READ 8w0
#define REG_WRITE 8w1

// switchID register
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(2)
extern void switchID_reg_rw(in bit<2> index, in bit<31> newVal, in bit<8> opCode, out bit<31> result);

// timestamp generation
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void tin_timestamp(in bit<1> valid, out bit<31> result);

#define SWITCH_ID_MASK 5w0b10000
#define SWITCH_ID_POS 4 
#define INGRESS_PORT_ID_MASK 5w0b01000
#define INGRESS_PORT_ID_POS 3
#define Q_OCCUPANCY_MASK 5w0b00100
#define Q_OCCUPANCY_POS 2
#define INGRESS_TSTAMP_MASK 5w0b00010
#define INGRESS_TSTAMP_POS 1
#define EGRESS_PORT_ID_MASK 5w0b00001
#define EGRESS_PORT_ID_POS 0 

// 4 bytes
#define INT_DATA_SIZE 4

// standard Ethernet header
header Ethernet_h { 
    EthernetAddress dstAddr; 
    EthernetAddress srcAddr; 
    bit<16> etherType;
}

// INT header
header int_h {
    bit<2> ver;                   // version #
    bit<2> rep;                   // replication requested
    bit<1> c;                     // is copy 
    bit<1> e;                     // max hop count exceeded
    bit<5> rsvd1;                 // reserved 1 
    bit<5> ins_cnt;               // # of 1's in instruction bitmask
    bit<8> max_hop_cnt;           // max # hops allowed to add metadata
    bit<8> total_hop_cnt;         // # hops that have added metadata 
    bit<5> instruction_bitmask;   // which metadata to add to packet
    bit<27> rsvd2;                // reserved 2
}

// INT switch ID header
header int_switch_id_h {
    bit<1> bos;
    bit<31> switch_id;
}

// INT ingress port ID header
header int_ingress_port_id_h {
    bit<1> bos;
    bit<31> ingress_port_id;
}

// INT queue occupancy header (bytes)
header int_q_occupancy_h {
    bit<1> bos;
    bit<31> q_occupancy;
}

// INT ingress timestamp header
header int_ingress_tstamp_h {
    bit<1> bos;
    bit<31> ingress_tstamp;
}

// INT egress port ID header
header INT_egress_port_id_h {
    bit<1> bos;
    bit<31> egress_port_id;
}

// List of all recognized headers
struct Parsed_packet { 
    Ethernet_h ethernet; 
    int_h INT;
    int_switch_id_h int_switch_id;
    int_ingress_port_id_h int_ingress_port_id;
    int_q_occupancy_h int_q_occupancy;
    int_ingress_tstamp_h int_ingress_tstamp;
    INT_egress_port_id_h int_egress_port_id; 
}

// user defined metadata: can be used to shared information between
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
            INT_TYPE: parse_int;
            default: reject;
        } 
    }

    state parse_int {
        b.extract(p.INT);
        transition accept;
    }
}

// match-action pipeline
control setBosPipe(inout Parsed_packet p,
                   inout user_metadata_t user_metadata,
                   inout digest_data_t digest_data,
                   inout sume_metadata_t sume_metadata) {

    apply {
        // set bos bits

        bit<5> headers_pushed_cnt = 0;
        if ((p.INT.instruction_bitmask & SWITCH_ID_MASK) >> SWITCH_ID_POS == 1) {
            headers_pushed_cnt = headers_pushed_cnt + 1;
            if (p.INT.total_hop_cnt == 0 && headers_pushed_cnt == p.INT.ins_cnt) {
                // last INT header in stack
                p.int_switch_id.bos = 1;
            } else {
                p.int_switch_id.bos = 0;
            }
            p.int_switch_id.setValid();
            sume_metadata.pkt_len = sume_metadata.pkt_len + INT_DATA_SIZE;
        }

        if ((p.INT.instruction_bitmask & INGRESS_PORT_ID_MASK) >> INGRESS_PORT_ID_POS == 1) {
            headers_pushed_cnt = headers_pushed_cnt + 1;
            if (p.INT.total_hop_cnt == 0 && headers_pushed_cnt == p.INT.ins_cnt) {
                // last INT header in stack
                p.int_ingress_port_id.bos = 1;
            } else {
                p.int_ingress_port_id.bos = 0;
            }
            p.int_ingress_port_id.setValid();
            sume_metadata.pkt_len = sume_metadata.pkt_len + INT_DATA_SIZE;
        }

        if ((p.INT.instruction_bitmask & Q_OCCUPANCY_MASK) >> Q_OCCUPANCY_POS == 1) {
            headers_pushed_cnt = headers_pushed_cnt + 1;
            if (p.INT.total_hop_cnt == 0 && headers_pushed_cnt == p.INT.ins_cnt) {
                // last INT header in stack
                p.int_q_occupancy.bos = 1;
            } else {
                p.int_q_occupancy.bos = 0;
            }
            p.int_q_occupancy.setValid();
            sume_metadata.pkt_len = sume_metadata.pkt_len + INT_DATA_SIZE;
        }

        if ((p.INT.instruction_bitmask & INGRESS_TSTAMP_MASK) >> INGRESS_TSTAMP_POS == 1) {
            headers_pushed_cnt = headers_pushed_cnt + 1;
            if (p.INT.total_hop_cnt == 0 && headers_pushed_cnt == p.INT.ins_cnt) {
                // last INT header in stack
                p.int_ingress_tstamp.bos = 1;
            } else {
                p.int_ingress_tstamp.bos = 0;
            }
            p.int_ingress_tstamp.setValid();
            sume_metadata.pkt_len = sume_metadata.pkt_len + INT_DATA_SIZE;
        }

        if ((p.INT.instruction_bitmask & EGRESS_PORT_ID_MASK) >> EGRESS_PORT_ID_POS == 1) {
            headers_pushed_cnt = headers_pushed_cnt + 1;
            if (p.INT.total_hop_cnt == 0 && headers_pushed_cnt == p.INT.ins_cnt) {
                // last INT header in stack
                p.int_egress_port_id.bos = 1;
            } else {
                p.int_egress_port_id.bos = 0;
            }
            p.int_egress_port_id.setValid();
            sume_metadata.pkt_len = sume_metadata.pkt_len + INT_DATA_SIZE;
        }

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

    setBosPipe() setBosPipe_inst;

    apply {

        forward.apply();

        if (p.INT.isValid()) {
            if (p.INT.total_hop_cnt >= p.INT.max_hop_cnt) {
                // INT data cannot be inserted
                p.INT.e = 1;
            } else {
                // fill INT header fields
                p.int_egress_port_id.egress_port_id = (bit<31>)sume_metadata.dst_port;
                tin_timestamp(1w1, p.int_ingress_tstamp.ingress_tstamp);
                p.int_ingress_port_id.ingress_port_id = (bit<31>)sume_metadata.src_port;

                // write output queue size
                if (sume_metadata.dst_port == 8w0b0000_0001) {
                    p.int_q_occupancy.q_occupancy = (bit<31>)sume_metadata.nf0_q_size;
                } else if (sume_metadata.dst_port == 8w0b0000_0100) {
                    p.int_q_occupancy.q_occupancy = (bit<31>)sume_metadata.nf1_q_size;
                } else if (sume_metadata.dst_port == 8w0b0001_0000) {
                    p.int_q_occupancy.q_occupancy = (bit<31>)sume_metadata.nf2_q_size;
                } else if (sume_metadata.dst_port == 8w0b0100_0000) {
                    p.int_q_occupancy.q_occupancy = (bit<31>)sume_metadata.nf3_q_size;
                } else {
                    p.int_q_occupancy.q_occupancy = 31w0x7FFF_FFFF; // special value meaning not currently available
                }
 
                bit<31> newVal = 0; // not used
                bit<8> opCode = REG_READ;
                bit<31> switchID;
                switchID_reg_rw(0, newVal, opCode, switchID);
                p.int_switch_id.switch_id = switchID;

                // Set the bos bits for each field
                setBosPipe_inst.apply(p, user_metadata, digest_data, sume_metadata);

                // increment total_hop_cnt
                p.INT.total_hop_cnt = p.INT.total_hop_cnt + 1;

            }
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
        // only headers marked as valid will be emitted
        b.emit(p.ethernet); 
        b.emit(p.INT);
        b.emit(p.int_switch_id);
        b.emit(p.int_ingress_port_id);
        b.emit(p.int_q_occupancy);
        b.emit(p.int_ingress_tstamp);
        b.emit(p.int_egress_port_id);
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;

