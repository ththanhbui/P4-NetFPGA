//----------------------------------------------------------------------------
//   This file is owned and controlled by Xilinx and must be used solely    //
//   for design, simulation, implementation and creation of design files    //
//   limited to Xilinx devices or technologies. Use with non-Xilinx         //
//   devices or technologies is expressly prohibited and immediately        //
//   terminates your license.                                               //
//                                                                          //
//   XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" SOLELY   //
//   FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY   //
//   PROVIDING THIS DESIGN, CODE, OR INFORMATION AS ONE POSSIBLE            //
//   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR STANDARD, XILINX IS     //
//   MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION IS FREE FROM ANY     //
//   CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE FOR OBTAINING ANY      //
//   RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY      //
//   DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE  //
//   IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR         //
//   REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF        //
//   INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A  //
//   PARTICULAR PURPOSE.                                                    //
//                                                                          //
//   Xilinx products are not intended for use in life support appliances,   //
//   devices, or systems.  Use in such applications are expressly           //
//   prohibited.                                                            //
//                                                                          //
//   (c) Copyright 1995-2017 Xilinx, Inc.                                   //
//   All rights reserved.                                                   //
//----------------------------------------------------------------------------
#ifndef _SUME_SWITCH_P4_
#define _SUME_SWITCH_P4_

// File "simple_sume_switch.p4"
// NetFPGA SUME P4 Switch declaration
// core library needed for packet_in definition
#include <core.p4>

// one-hot encoded: {DMA, NF3, DMA, NF2, DMA, NF1, DMA, NF0}
typedef bit<8> port_t;

/*
Output metadata format:
[15:0]    pkt_len        (bit<32>)
[23:16]   src_port       (bit<8>)
[31:24]   dst_port       (bit<8>)
[63:32]   enq_data       (bit<32>)
[95:64]   deq_data       (bit<32>)
[127:96]  drop_data      (bit<32>)
[135:128] enq_port       (bit<8>)
[143:136] deq_port       (bit<8>)
[151:144] drop_port      (bit<8>)
[183:152] timer_period   (bit<32>) - measured in 20ns increments
[231:184] timer_now      (bit<48>) - measured in 20ns increments
[235:232] link_status    (bit<4>) - <nf3>-<nf2>-<nf1>-<nf0>
[236]     pkt_trigger    (bit<1>)
[237]     enq_trigger    (bit<1>)
[238]     deq_trigger    (bit<1>)
[239]     drop_trigger   (bit<1>)
[240]     timer_trigger  (bit<1>)
[241]     link_trigger   (bit<1>)
[242]     gen_packet     (bit<1>)
[247:243] unused         (bit<5>)
*/

/* standard sume switch metadata */
struct sume_metadata_t {
    bit<5> unused;
    bit<1> gen_packet;
    bit<1> link_trigger;
    bit<1> timer_trigger;
    bit<1> drop_trigger;
    bit<1> deq_trigger;
    bit<1> enq_trigger;
    bit<1> pkt_trigger;
    bit<4> link_status;
    bit<48> timer_now;
    bit<32> timer_period;
    port_t drop_port;
    port_t deq_port;
    port_t enq_port;
    bit<32> drop_data;
    bit<32> deq_data;
    bit<32> enq_data;
    port_t dst_port;
    port_t src_port;
    bit<16> pkt_len;
}

/**
 * Programmable parser.
 * @param b input packet
 * @param <H> type of headers; defined by user
 * @param parsedHeaders headers constructed by parser
 * @param <M> type of metadata; defined by user
 * @param metadata; metadata constructed by parser
 * @param sume_metadata; standard metadata for the sume switch
 */
parser Parser<H, M, D>(packet_in b,
                       out H parsedHeaders,
                       out M user_metadata,
                       out D digest_data,
                       inout sume_metadata_t sume_metadata);

/**
 * Match-action pipeline
 * @param <H> type of input and output headers
 * @param parsedHeaders; headers received from the parser and sent to the deparser
 * @param <M> type of input and output user metadata
 * @param user_metadata; metadata defined by the user
 * @param sume_metadata; standard metadata for the sume switch
 */
control Pipe<H, M, D>(inout H parsedHeaders,
                      inout M user_metadata,
                      inout D digest_data,
                      inout sume_metadata_t sume_metadata);

/**
 * Switch deparser.
 * @param b output packet
 * @param <H> type of headers; defined by user
 * @param parsedHeaders headers for output packet
 * @param <M> type of metadata; defined by user
 * @param user_metadata; defined by user
 * @param sume_metadata; standard metadata for the sume switch
 */
control Deparser<H, M, D>(packet_out b,
                          in H parsedHeaders,
                          in M user_metadata,
                          inout D digest_data,
                          inout sume_metadata_t sume_metadata);

/**
 * Top-level package declaration - must be instantiated by user.
 * The arguments to the package indicate blocks that
 * must be instantiated by the user.
 * @param <H> user-defined type of the headers processed.
 */
package SimpleSumeSwitch<H, M, D>(Parser<H, M, D> p,
                                  Pipe<H, M, D> map,
                                  Deparser<H, M, D> d);

#endif  /* _SUME_SWITCH_P4_ */
