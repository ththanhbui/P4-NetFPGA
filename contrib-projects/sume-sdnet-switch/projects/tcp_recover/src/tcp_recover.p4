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
 * Template P4 project for SimpleSumeSwitch 
 *
 */

typedef bit<48> EthAddr_t; 
typedef bit<32> IPv4Addr_t;

#define IPV4_TYPE 0x0800
#define TCP_TYPE 6

#define FIN_MASK 8w0b0000_0001
#define FIN_POS 0

#define SYN_MASK 8w0b0000_0010
#define SYN_POS 1

#define ACK_MASK 8w0b0001_0000
#define ACK_POS 4

#define REG_READ   8w0
#define REG_WRITE  8w1
#define REG_ADD    8w2
#define REG_SUB    8w3

#define EQ_RELOP    8w0
#define NEQ_RELOP   8w1
#define GT_RELOP    8w2
#define LT_RELOP    8w3

#define HASH_WIDTH 5

#define PKT_SIZE 7 // pkt_size is 128 

#define UNUSED 8w0b0000_0000
#define PADDING_80 48w0
#define nf0 8w0b0000_0001
#define nf1 8w0b0000_0100
#define nf2 8w0b0001_0000
#define nf3 8w0b0100_0000


// hash function
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void hash_lrc(in bit<104> in_data, out bit<HASH_WIDTH> result);

// latest_seq_no register
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void seq_no_reg_praw(in bit<HASH_WIDTH> index,
                             in bit<32> newVal,
                             in bit<32> incVal,
                             in bit<8> opCode,
                             in bit<32> compVal,
                             in bit<8> relOp, 
                             out bit<32> result,
                             out bit<1> boolean);

// earliest_seq_no register
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void earliest_seq_no_reg_praw(in bit<HASH_WIDTH> index,
                                        in bit<32> newVal,
                                        in bit<32> incVal,
                                        in bit<8> opCode,
                                        in bit<32> compVal,
                                        in bit<8> relOp,
                                        out bit<32> result,
                                        out bit<1> boolean);
                                                                 

// pkts_cached_cnt 
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void pkts_cached_cnt_reg_raw(in bit<HASH_WIDTH> index,
                                        in bit<32> newVal,
                                        in bit<32> incVal,
                                        in bit<8> opCode,
                                        out bit<32> result);

// ack_cnt register
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void ack_cnt_reg_praw(in bit<HASH_WIDTH> index,
                             in bit<32> newVal,
                             in bit<32> incVal,
                             in bit<8> opCode,
                             in bit<32> compVal,
                             in bit<8> relOp, 
                             out bit<32> result,
                             out bit<1> boolean);

// retransmit_cnt register
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void retransmit_cnt_reg_ifElseRaw(in bit<HASH_WIDTH> index_2,
                                        in bit<32> newVal_2,
                                        in bit<32> incVal_2,
                                        in bit<8> opCode_2,
                                        in bit<HASH_WIDTH> index_1,
                                        in bit<32> newVal_1,
                                        in bit<32> incVal_1,
                                        in bit<8> opCode_1,
                                        in bit<HASH_WIDTH> index_comp,
                                        in bit<32> compVal,
                                        in bit<8> relOp,
                                        out bit<32> result,
                                        out bit<1> boolean);

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

// user defined metadata: can be used to shared information between
// TopParser, TopPipe, and TopDeparser 
struct user_metadata_t {
    bit<8>  unused;
}

// digest data to be sent to CPU if desired. MUST be 256 bits!
struct digest_data_t {
    bit<72>  unused;
    bit<104> flow_id;
    bit<80> tuser;
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
        digest_data.flow_id = 0;
        digest_data.tuser = 0;
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

    action cache_write(port_t port) {
        bit<8> cache_port; 
        cache_port = (port & 1) |
                     (((port >> 2) & 1) << 1) |
                     (((port >> 4) & 1) << 2) |
                     (((port >> 6) & 1) << 3) |
                     (( ((port >> 1) & 1) | ((port >> 3) & 1) | ((port >> 5) & 1) | ((port >> 7) & 1) ) << 4);
        digest_data.tuser = PADDING_80++UNUSED++UNUSED++UNUSED++cache_port;
    }

    action cache_read(port_t port) {
        bit<8> cache_port;
        cache_port = (port & 1) |
                     (((port >> 2) & 1) << 1) |
                     (((port >> 4) & 1) << 2) |
                     (((port >> 6) & 1) << 3) |
                     (( ((port >> 1) & 1) | ((port >> 3) & 1) | ((port >> 5) & 1) | ((port >> 7) & 1) ) << 4);
        digest_data.tuser = PADDING_80++8w1++UNUSED++cache_port++UNUSED;
    }

    action cache_drop(port_t port, bit<32> drop_count) {
        bit<8> cache_port;
        cache_port = (port & 1) |
                     (((port >> 2) & 1) << 1) |
                     (((port >> 4) & 1) << 2) |
                     (((port >> 6) & 1) << 3) |
                     (( ((port >> 1) & 1) | ((port >> 3) & 1) | ((port >> 5) & 1) | ((port >> 7) & 1) ) << 4);
        digest_data.tuser = 24w0++drop_count++cache_port++UNUSED++UNUSED;
    }

    action compute_flow_id(bit<1> i) {
        if (i == 1) { // is an ACK -- compute flow_id with src and dst swapped
            digest_data.flow_id = p.ip.dstAddr++p.ip.srcAddr++p.ip.protocol++p.tcp.dstPort++p.tcp.srcPort;
        } else { // 'send' direction
            digest_data.flow_id = p.ip.srcAddr++p.ip.dstAddr++p.ip.protocol++p.tcp.srcPort++p.tcp.dstPort;
        }
    }

    table retransmit {
        key = { digest_data.flow_id: exact; }

        actions = {
            set_output_port;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
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
            bit<1> ack_;
            // check if it's an ACK packet to compute flow_id
            if ((p.tcp.flags & ACK_MASK) >> ACK_POS == 1) { // Is an ACK packet
                ack_ = 1;               
            } else { // not an ACK packet
                ack_ = 0;
            }

            // compute the flow_id accordingly
            compute_flow_id(ack_);

            // if the flow_id is in our match-action table, apply our fast recover, otherwise do nothing
            if (retransmit.apply().hit) {
                // metadata for index register access
                bit<HASH_WIDTH> hash_result;
                // compute hash of 5-tuple to obtain index for seq_no register 
                hash_lrc(digest_data.flow_id, hash_result);

                // read the latest seqNo -- access seq_no_reg_praw
                // metadata for register access
                bit<1> greater;
                bit<32> latestSeqNo;
                bit<32> seq_no_compVal;

                if (ack_ == 1) { // Is an ACK packet
                    seq_no_compVal = 0; // just want to read the latest seqNo
                } else {
                    seq_no_compVal = p.tcp.seqNo;
                }
                
                seq_no_reg_praw(hash_result, seq_no_compVal, 0, REG_WRITE, seq_no_compVal, GT_RELOP, latestSeqNo, greater);
                /* if it is not an ACK & p.tcp.seqNo > latestSeqNo, overwrite reg[index] with p.tcp.seqNo
                 *  --> greater is True
                 * if it is an ACK, read the latest seqNo to latestSeqNo register
                 *  --> greater is False because 0 is not greater than current value at seq_no[index]
                 */

                // access earliest_seq_no_reg_praw -- the earliest seqNo in our cache 
                // metadata for register access
                bit<1> use_earliest_seq_no;
                bit<32> earliest_newVal;
                bit<8> earliest_relOp;
                bit<32> earliest_result; // the earliest seqNo in our cache
                bit<1> earliest_true;

                if (ack_ == 0) {
                    earliest_newVal = p.tcp.seqNo;
                    earliest_relOp = EQ_RELOP; // initialise the earliestSeqNo if it has not been init
                    use_earliest_seq_no = 1;
                }
                if ((ack_ == 1) && (p.tcp.ackNo <= latestSeqNo)) {
                    earliest_newVal = p.tcp.ackNo;
                    earliest_relOp = GT_RELOP; // always true
                    use_earliest_seq_no = 1;
                }
                if (use_earliest_seq_no == 1) {
                    earliest_seq_no_reg_praw(hash_result, earliest_newVal, 0, REG_WRITE, 
                            32w0, earliest_relOp, earliest_result, earliest_true);
                } // write to the register, but the previous result is stored in earliest_result
                
                bit<32> dropCount=0;  // the number of pkts dropped -- calculate this to update pkts_cached_cnt_reg_raw
                if ((ack_ == 1) && !(p.tcp.ackNo > latestSeqNo)) {
                    dropCount = (p.tcp.ackNo-earliest_result) >> PKT_SIZE ;
                }

                // access the pkts_cached_cnt_reg_raw -- the number of pkts cached
                // metadata for register access
                bit<1> use_pkts_cached_cnt = 0;
                bit<32> pkts_cached_newVal = 0;
                bit<32> pkts_cached_incVal;
                bit<8> pkts_cached_opCode;
                bit<32> pkts_cached_result;         // the number of pkts cached

                if (ack_ == 0) {
                    pkts_cached_incVal = 1;
                    pkts_cached_opCode = REG_ADD;
                    use_pkts_cached_cnt = 1;
                } else { // ack_ == 1
                    if (p.tcp.ackNo > latestSeqNo) {
                        pkts_cached_incVal = 0;
                        pkts_cached_opCode = REG_WRITE;
                    } else {
                        pkts_cached_incVal = dropCount;
                        pkts_cached_opCode = REG_SUB;
                    }
                    use_pkts_cached_cnt = 1;
                }

                if (use_pkts_cached_cnt == 1) {
                    pkts_cached_cnt_reg_raw(hash_result, pkts_cached_newVal, pkts_cached_incVal, 
                                    pkts_cached_opCode, pkts_cached_result);
                }


                // access the ack_cnt_reg_praw -- the number of time a DUP ACK is seen
                bit<32> ack_cnt_newVal;
                bit<32> ack_cnt_incVal;
                bit<8> ack_cnt_opCode;
                bit<32> ack_cnt_compVal;
                bit<8> ack_cnt_relOp;
                bit<32> ack_cnt_result; // the ack_cnt
                bit<1> ack_cnt_true;

                if (ack_ == 1) {
                    if (p.tcp.ackNo > latestSeqNo) {
                        ack_cnt_newVal = 0;
                        ack_cnt_incVal = 0;
                        ack_cnt_opCode = REG_WRITE; // reset ack_cnt
                        ack_cnt_compVal = 5;
                        ack_cnt_relOp = LT_RELOP; // always true, since ack_cnt never get more than 3
                        // use_ack_cnt = 1;
                    } else {
                        ack_cnt_newVal = 0;
                        ack_cnt_incVal = 1;
                        ack_cnt_opCode = REG_ADD;
                        ack_cnt_compVal = 3; // if ack_cnt < 3, ack_cnt++
                        ack_cnt_relOp = LT_RELOP;
                        // use_ack_cnt = 1;
                    }
                    ack_cnt_reg_praw(hash_result, ack_cnt_newVal, ack_cnt_incVal, ack_cnt_opCode, 
                            ack_cnt_compVal, ack_cnt_relOp, ack_cnt_result, ack_cnt_true);
                }
                

                // access the retransmit_cnt_reg_ifElseRaw -- the number of time we retransmit
                // metadata for register access
                bit<32> retransmit_newVal_2;
                bit<32> retransmit_incVal_2;
                bit<8> retransmit_opCode_2;
                bit<32> retransmit_newVal_1;
                bit<32> retransmit_incVal_1;
                bit<8> retransmit_opCode_1;
                bit<32> retransmit_compVal;
                bit<8> retransmit_relOp;
                bit<32> retransmit_result; // the retransmit_cnt
                bit<1> retransmit_boolean;

                if (ack_ == 1) {
                    if (p.tcp.ackNo > latestSeqNo) { // reset retransmit_cnt
                        retransmit_newVal_2 = 0; 
                        retransmit_incVal_2 = 0;
                        retransmit_opCode_2 = REG_WRITE;
                        retransmit_newVal_1 = 0;
                        retransmit_incVal_1 = 0;
                        retransmit_opCode_1 = REG_WRITE;
                        retransmit_compVal = 0;
                        retransmit_relOp = EQ_RELOP;
                    } else {
                        if (ack_cnt_true == 0) { // ack_cnt >= 3
                            retransmit_newVal_2 = 0;   // if retransmit_cnt == 0, add 1
                            retransmit_incVal_2 = 1;
                            retransmit_opCode_2 = REG_ADD;
                            retransmit_newVal_1 = 0;  // if retransmit_cnt == 1, reset
                            retransmit_incVal_1 = 0;
                            retransmit_opCode_1 = REG_WRITE;
                            retransmit_compVal = 1;
                            retransmit_relOp = EQ_RELOP;
                        }
                    }    
                    
                    retransmit_cnt_reg_ifElseRaw(hash_result,
                                        retransmit_newVal_2,
                                        retransmit_incVal_2,
                                        retransmit_opCode_2,
                                        hash_result,
                                        retransmit_newVal_1,
                                        retransmit_incVal_1,
                                        retransmit_opCode_1,
                                        hash_result,
                                        retransmit_compVal,
                                        retransmit_relOp,
                                        retransmit_result,
                                        retransmit_boolean);
                }       

                cache_write(sume_metadata.dst_port);
                cache_drop(sume_metadata.src_port, dropCount);
                cache_read(sume_metadata.src_port);         
            }
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
        b.emit(p.tcp);
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;



    

                //     if (true_ == 1) {  if (p.tcp.seqNo > latestSeqNo)
                //          new package -- add pkt to cache_queue
                //         cache_write(sume_metadata.dst_port);

                //          increment pkts_cached register
                //          pkts_cached_cnt_reg_raw(hash_result, 0, 1, REG_ADD, pkts_cached);
                //     }  else it's an old pkt that we have already cached -- do nothing

                //  is an ACK pkt and p
                // if (ack_ && (p.tcp.ackNo > latestSeqNo)) {                       
                //      this ackNo is more than latestSeqNo -- update, drop all cached pkts and reset counters
                //     pkts_cached_cnt_reg_raw(hash_result, 0, 0, REG_READ, dropCount);

                //      drop cached pkts
                //     cache_drop(sume_metadata.src_port, dropCount);

                //      reset counters
                //      ack_cnt_reg_raw(hash_result, 0, 0, REG_WRITE, ackCnt);
                //      retransmit_cnt_reg_raw(hash_result, 0, 0, REG_WRITE, retransmitCnt);
                //      pkts_cached_cnt_reg_raw(hash_result, 0, 0, REG_WRITE, dropCount);

                //      } else {
                //           drop some pkts -- e.g. cache 1, 2, 3; receive ack 2 --> drop 1
                //           calculate number of pkts to drop 
                //          pkts_cached_cnt_reg_raw(hash_result, 0, 0, REG_READ, pktsCached);  number of pkts cached
                //          earliest_seq_no_reg_raw(hash_result, 0, 0, REG_READ, earliestSeqNo);  earliest seqNo          
                //          dropCount = ((p.tcp.ackNo-earliestSeqNo)/PKT_SIZE);

                //     if (dropCount > 0) {
                //         cache_drop(sume_metadata.src_port, dropCount);
                //     }

                //           update pkts_cached_cnt & earliest_seq_no registers
                //          pkts_cached_cnt_reg_raw(hash_result, pktsCached-dropCount, 0, REG_WRITE, pktsCached);
                //          earliest_seq_no_reg_raw(hash_result, p.tcp.ackNo, 0, REG_WRITE, earliestSeqNo);

                //           read ackCnt
                //          ack_cnt_reg_raw(hash_result, 0, 0, REG_READ, ackCnt);

                //          if (ackCnt < 3) {
                //               if ackCnt < 3, send pkt to src "as-is" & increment ackCnt
                //              ack_cnt_reg_raw(hash_result, 0, 1, REG_ADD, ackCnt);
                //          } else {
                //               ackCnt >= 3, read retransmitCnt
                //              retransmit_cnt_reg_raw(hash_result, 0, 0, REG_READ, retransmitCnt);

                //              if (retransmitCnt == 0) {
                //                   haven't retransmitted -- retransmitCnt < N = 1
                //                   resend pkt
                //                  cache_read(sume_metadata.src_port);

                //                   retransmitCnt++
                //                  retransmit_cnt_reg_raw(hash_result, 0, 1, REG_ADD, retransmitCnt);

                //      send this pkt to host with ACK flag = 0
                //     p.tcp.flags = p.tcp.flags ^ ACK_MASK;
                //              } else {
                //                   already retransmitted -- send pkt to src "as-is"
                //                   reset retransmitCnt
                //                  retransmit_cnt_reg_raw(hash_result, 0, 0, REG_WRITE, retransmitCnt);
                //              }
                //          }

