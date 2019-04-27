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
 * tcp_recover.p4
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

#define PKT_SIZE 6 // pkt_size is 64 bytes

#define INT_MAX 4294967295
#define UNUSED 8w0
#define PADDING_80 48w0
#define nf0 0b0000_0001
#define nf1 0b0000_0100
#define nf2 0b0001_0000
#define nf3 0b0100_0000


// hash function
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(0)
extern void hash_lrc(in bit<104> in_data, out bit<HASH_WIDTH> result);

// latest_seq_no register
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void seq_no_reg_praw(in bit<HASH_WIDTH> index,
                             in bit<32> newVal,
                             in bit<32> incVal,
                             in bit<8> opCode,
                             in bit<32> compVal,
                             in bit<8> relOp, 
                             out bit<32> result,
                             out bit<1> boolean);

// latest_ack_no register
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void latest_ack_no_reg_praw(in bit<HASH_WIDTH> index,
                                    in bit<32> newVal,
                                    in bit<32> incVal,
                                    in bit<8> opCode,
                                    in bit<32> compVal,
                                    in bit<8> relOp,
                                    out bit<32> result,
                                    out bit<1> boolean);
                                                                 

// pkts_cached_cnt 
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(HASH_WIDTH)
extern void pkts_cached_cnt_reg_raw(in bit<HASH_WIDTH> index,
                                    in bit<32> newVal,
                                    in bit<32> incVal,
                                    in bit<8> opCode,                                  
                                    out bit<32> result);

// ack_cnt register
@Xilinx_MaxLatency(64)
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
@Xilinx_MaxLatency(64)
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
    bit<80> tuser;      /*  [7:0]    cache_write; // encoded:  {0, 0, 0, DMA, NF3, NF2, NF1, NF0}
                         *  [15:8]   cache_read;  // encoded:  {0, 0, 0, DMA, NF3, NF2, NF1, NF0}
                         *  [23:16]  cache_drop;  // encoded:  {0, 0, 0, DMA, NF3, NF2, NF1, NF0}
                         *  [31:24]  cache_count; // number of packets to read or drop;
                         *  [79:32]  unused 
                         */
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

    table forward {
        key = { p.ethernet.dstAddr: exact; }

        actions = {
            set_output_port;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    table retransmit {
        key = { digest_data.flow_id: exact; }

        actions = {
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    apply {
        if (!forward.apply().hit) {
            sume_metadata.dst_port = 0;
        } else {
            if (p.tcp.isValid()) {
                bit<1> ack_;
                // check if it's an ACK packet to compute flow_id
                if ((p.tcp.flags & ACK_MASK) >> ACK_POS == 1) { // Is an ACK packet
                    ack_ = 1;   
                    compute_flow_id(1);      // compute flow_id with src and dst swapped      
                } else { // not an ACK packet
                    ack_ = 0;
                    compute_flow_id(0);
                }

                // if the flow_id is in our match-action table, apply our fast recover, otherwise do nothing
                if (retransmit.apply().hit) {                    
                    // metadata for index register access
                    bit<HASH_WIDTH> hash_result;
                    // compute hash of 5-tuple to obtain index for seq_no register 
                    hash_lrc(digest_data.flow_id, hash_result);

                    // read the latest seqNo -- access seq_no_reg_praw
                    // metadata for register access
                    bit<1> new_packet;
                    bit<32> latestSeqNo;
                    bit<32> seq_no_compVal;

                    // access latest_ack_no_reg_praw -- the most recent ackNo
                    // metadata for register access
                    bit<1> use_latest_ack_no = 0;
                    bit<32> latest_newVal=0;
                    bit<32> latest_compVal=0;
                    bit<8> latest_relOp=0;
                    bit<32> latest_result = 0;            // the latest ackNo
                    bit<1> latest_true=0;

                    // access the pkts_cached_cnt_reg_raw -- the number of pkts cached
                    // metadata for register access
                    bit<1> use_pkts_cached_cnt = 0;
                    bit<32> pkts_cached_newVal = 0;
                    bit<32> pkts_cached_incVal = 0;
                    bit<8> pkts_cached_opCode = REG_READ;
                    bit<32> pkts_cached_result = 0;         // the number of pkts cached

                    // access the ack_cnt_reg_praw -- the number of time a DUP ACK is seen
                    bit<1> use_ack_cnt = 0;
                    bit<32> ack_cnt_newVal = 0;
                    bit<32> ack_cnt_incVal = 0;
                    bit<8> ack_cnt_opCode = REG_READ;
                    bit<32> ack_cnt_compVal = 0;
                    bit<8> ack_cnt_relOp = EQ_RELOP;
                    bit<32> ack_cnt_result;             // the ack_cnt
                    bit<1> ack_cnt_true = 1;

                    // access the retransmit_cnt_reg_ifElseRaw -- the number of time we retransmit
                    // metadata for register access
                    bit<1> use_retransmit_cnt = 0;
                    bit<32> retransmit_newVal_2 = 0;
                    bit<32> retransmit_incVal_2 = 0;
                    bit<8> retransmit_opCode_2 = REG_READ;
                    bit<32> retransmit_newVal_1 = 0;
                    bit<32> retransmit_incVal_1 = 0;
                    bit<8> retransmit_opCode_1 = REG_READ;
                    bit<32> retransmit_compVal = 0;
                    bit<8> retransmit_relOp = EQ_RELOP;
                    bit<32> retransmit_result;          //  the retransmit_cnt
                    bit<1> retransmit_boolean = 1;      //  default: don't retransmit -- retransmit_cnt = 1

                    bit<32> dropCount=0;  // the number of pkts dropped -- calculate this to update pkts_cached_cnt_reg_raw
    
                    if (ack_ == 0) {  
                        if ((p.tcp.flags & SYN_MASK) >> SYN_POS == 1) { // initialise the latest_ack for the first packet
                            seq_no_compVal = INT_MAX;
                            
                            latest_newVal = p.tcp.seqNo;
                            latest_compVal = 0; 
                            latest_relOp = LT_RELOP; // always true -- 0 < current value
                            use_latest_ack_no = 1;

                            // reset all other registers

                            // reset ack_cnt
                            ack_cnt_incVal = 0;
                            ack_cnt_opCode = REG_WRITE;
                            ack_cnt_compVal = 3;
                            ack_cnt_relOp = LT_RELOP; // always true, since ack_cnt never get more than 3
                            use_ack_cnt = 1;

                            // reset retransmit_cnt
                            retransmit_newVal_2 = 0; 
                            retransmit_incVal_2 = 0;
                            retransmit_opCode_2 = REG_WRITE;
                            retransmit_newVal_1 = 0;
                            retransmit_incVal_1 = 0;
                            retransmit_opCode_1 = REG_WRITE;
                            retransmit_compVal = 0;
                            retransmit_relOp = EQ_RELOP;
                            use_retransmit_cnt = 1;

                        } else { // not a SYN packet
                            seq_no_compVal = p.tcp.seqNo;
                        }
                    } else { // ack_ == 1
                        seq_no_compVal = 0; // just want to read the latest seqNo

                        latest_newVal = p.tcp.ackNo;
                        latest_compVal = p.tcp.ackNo;
                        latest_relOp = GT_RELOP; // true if p.tcp.ackNo > latest_ackNo
                        use_latest_ack_no = 1;
                    }

                    seq_no_reg_praw(hash_result, p.tcp.seqNo, 0, REG_WRITE, seq_no_compVal, GT_RELOP, latestSeqNo, new_packet);
                    /* if it is not an ACK & p.tcp.seqNo > latestSeqNo, overwrite reg[index] with p.tcp.seqNo
                    *  --> new_packet is True
                    *  --> new_packet is False if p.tcp.seqNo <= latestSeqNo -- we got an old packet
                    * if it is an ACK, read the latest seqNo to latestSeqNo register
                    *  --> new_packet is False because 0 is not greater than current value at seq_no[index]
                    */

                    if (use_latest_ack_no == 1) {
                        latest_ack_no_reg_praw(hash_result, latest_newVal, 0, REG_WRITE, 
                                latest_compVal, latest_relOp, latest_result, latest_true);
                    } // write to the register, but the previous result is stored in latest_result
                      // latest_true == 1 if SYN packet or p.tcp.ackNo > latest_ackNo

                    if (ack_ == 0) {                      
                        if (new_packet == 1) {  // if (p.tcp.seqNo > latestSeqNo)
                            // new package -- add pkt to cache_queue
                            cache_write(sume_metadata.dst_port);

                            // increment pkts_cached register
                            use_pkts_cached_cnt = 1; 
                            if ((p.tcp.flags & SYN_MASK) >> SYN_POS == 1) { // SYN packet
                                pkts_cached_newVal = 1;
                                pkts_cached_opCode = REG_WRITE;
                            } else {
                                pkts_cached_incVal = 1;
                                pkts_cached_opCode = REG_ADD;
                            }          
                            use_pkts_cached_cnt = 1;       
                        } //  else it's an old pkt that we have already cached -- do nothing
                    } else { // ack_ == 1
                        ack_cnt_newVal = 0;

                        if (latest_true == 1) { // p.tcp.ackNo > latest_ackNo -- update latest_ackNo
                            // drop cached packets
                            if (p.tcp.ackNo <= latestSeqNo) {
                                dropCount = (p.tcp.ackNo-latest_result) >> PKT_SIZE ; //  calculate number of pkts to drop 
                                pkts_cached_incVal = dropCount;
                                pkts_cached_opCode = REG_SUB; // REG_SUB
                                cache_drop(sume_metadata.src_port, dropCount);  //  drop SOME pkts -- e.g. cache 1, 2, 3; 
                                                                                //  receive ack 2 --> drop 1
                            } else {
                                pkts_cached_incVal = 0;
                                pkts_cached_opCode = REG_WRITE; // suppose to be REG_WRITE
                            }
                            use_pkts_cached_cnt = 1;

                            // reset ack_cnt
                            ack_cnt_incVal = 0;
                            ack_cnt_opCode = REG_WRITE;
                            ack_cnt_compVal = 3;
                            ack_cnt_relOp = LT_RELOP; // always true, since ack_cnt never get more than 3

                            // reset retransmit_cnt
                            retransmit_newVal_2 = 0; 
                            retransmit_incVal_2 = 0;
                            retransmit_opCode_2 = REG_WRITE;
                            retransmit_newVal_1 = 0;
                            retransmit_incVal_1 = 0;
                            retransmit_opCode_1 = REG_WRITE;
                            retransmit_compVal = 0;
                            retransmit_relOp = EQ_RELOP;
                            use_retransmit_cnt = 1;

                        } else { // p.tcp.ackNo = latest_ackNo -- potential DUP ACK
                            ack_cnt_incVal = 1;
                            ack_cnt_opCode = REG_ADD;
                            ack_cnt_compVal = 2; // if ack_cnt < 2, ack_cnt++
                            ack_cnt_relOp = GT_RELOP;
                        }
                        use_ack_cnt = 1;
                    }

                    if (use_pkts_cached_cnt == 1) {
                        pkts_cached_cnt_reg_raw(hash_result, pkts_cached_newVal, pkts_cached_incVal, 
                                        pkts_cached_opCode, pkts_cached_result);
                    }

                    if ((ack_ == 1) && (latest_true == 1) && (p.tcp.ackNo > latestSeqNo)) {            
                        // p.tcp.ackNo > latestSeqNo -- update, drop all cached pkts and reset counters
                        // after pkts_cached_cnt register access --> pkts_cached_result should contain the total number of pkts
                        cache_drop(sume_metadata.src_port, 2);
                    }

                    if (use_ack_cnt == 1) {
                        ack_cnt_reg_praw(hash_result, ack_cnt_newVal, ack_cnt_incVal, ack_cnt_opCode, 
                                ack_cnt_compVal, ack_cnt_relOp, ack_cnt_result, ack_cnt_true);
                    }

                    if ((ack_ == 1) && (latest_true == 0) && (ack_cnt_true == 0)) { // ack_cnt >= 3
                        retransmit_newVal_2 = 0;   // if retransmit_cnt == 0, add 1
                        retransmit_incVal_2 = 1;
                        retransmit_opCode_2 = REG_ADD;
                        retransmit_newVal_1 = 0;  //  if retransmit_cnt == 1, already retransmitted -- send pkt to src "as-is"
                        retransmit_incVal_1 = 0;
                        retransmit_opCode_1 = REG_WRITE; //  reset retransmitCnt
                        retransmit_compVal = 1;
                        retransmit_relOp = EQ_RELOP;

                        use_retransmit_cnt = 1;
                    }

                    if (use_retransmit_cnt == 1) {
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

                    if ((ack_ == 1) && (latest_true == 0)
                            && (ack_cnt_true == 0) && (retransmit_boolean == 0)) {
                        // retransmit_compVal = 1; 
                        // retransmit_relOp = EQ_RELOP
                        // retransmit_boolean = 0 means retransmitCnt=0<N=1 --> haven't retransmitted --> resend pkt
                        cache_read(sume_metadata.src_port);

                        //  send this pkt to host with ACK flag = 0
                        p.tcp.flags = p.tcp.flags ^ ACK_MASK;
                    }
                }
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