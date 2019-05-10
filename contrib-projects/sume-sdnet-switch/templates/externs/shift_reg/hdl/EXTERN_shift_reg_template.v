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
 * File: @MODULE_NAME@.v 
 * Author: Stephen Ibanez
 * 
 * Auto-generated file.
 *
 * shift_reg
 *
 * Simple shift register.
 *
 */

/* P4 extern function prototype:

extern void <name>_shift_reg(in bit<INDEX_WIDTH> index_in,
                             in bit<DATA_WIDTH> data_in,
                             out bit<DATA_WIDTH> data_out);
*/

`timescale 1 ps / 1 ps

module @MODULE_NAME@ 
#(
    parameter L2_DEPTH = @L2_DEPTH@,
    parameter INDEX_WIDTH = @INDEX_WIDTH@,
    parameter DATA_WIDTH = @DATA_WIDTH@,
    parameter NUM_SHIFT_REGS = @NUM_SHIFT_REGS@
)
(
    // Data Path I/O
    input                                   clk_lookup,
    input                                   rst,
    input                                   tuple_in_@EXTERN_NAME@_input_VALID,
    input   [DATA_WIDTH:0]                  tuple_in_@EXTERN_NAME@_input_DATA,
    output                                  tuple_out_@EXTERN_NAME@_output_VALID,
    output  [DATA_WIDTH-1:0]                tuple_out_@EXTERN_NAME@_output_DATA
);


    localparam SR_DEPTH = 2**L2_DEPTH;

    // data plane state machine states
    localparam SR_FILL = 0;
    localparam SR_FULL = 1;

    wire valid_in;
    wire statefulValid_in;

    reg [DATA_WIDTH-1:0]          result_r, result_r_next;
    reg                           result_valid_r, result_valid_r_next;


    // data plane state machine signals
    reg                           sr_state, sr_state_next;
    reg [L2_DEPTH:0]              sr_count_r, sr_count_r_next;

    // shift register signals
    wire [DATA_WIDTH-1:0] sr_data_out;
    wire [DATA_WIDTH-1:0] sr_data_in;
    wire sr_full;
    wire sr_empty;
    wire sr_wr_en;
    reg sr_rd_en;

    //// Input buffer to hold requests ////
    fallthrough_small_fifo
    #(
        .WIDTH(DATA_WIDTH),
        .MAX_DEPTH_BITS(L2_DEPTH)
    )
    shift_reg_fifo
    (
       // Outputs
       .dout                           (sr_data_out),
       .full                           (sr_full),
       .nearly_full                    (),
       .prog_full                      (),
       .empty                          (sr_empty),
       // Inputs
       .din                            (sr_data_in),
       .wr_en                          (sr_wr_en),
       .rd_en                          (sr_rd_en),
       .reset                          (rst),
       .clk                            (clk_lookup)
    );

    // logic to parse inputs
    assign valid_in = tuple_in_@EXTERN_NAME@_input_VALID;
    assign {statefulValid_in, sr_data_in} = tuple_in_@EXTERN_NAME@_input_DATA;

    // logic to write to shift register
    assign sr_wr_en = valid_in & statefulValid_in;

    /* Shift Register Read State Machine */ 
    always @(*) begin
       // default values
       sr_state_next = sr_state;
       sr_count_r_next = sr_count_r;
       sr_rd_en = 0;

       // output signals
       result_valid_r_next = valid_in;
       result_r_next = 0;

       case(sr_state)
           SR_FILL: begin
               /* Shift register needs to fill up first */
               if (sr_wr_en) begin
                   sr_count_r_next = sr_count_r + 1;
                   if (sr_count_r == SR_DEPTH-1) begin
                       sr_state_next = SR_FULL;
                   end
               end
           end

           SR_FULL: begin
               /* Shift register is full */
               if (sr_wr_en) begin
                   sr_rd_en = 1;
                   result_r_next = sr_data_out; 
               end
           end
       endcase // case(sr_state)
    end // always @ (*)

    always @(posedge clk_lookup) begin
       if(rst) begin
          sr_state <= SR_FILL;
          sr_count_r <= 0;
          result_valid_r <= 0;
          result_r <= 0;
       end
       else begin
          sr_state <= sr_state_next;
          sr_count_r <= sr_count_r_next;
          result_valid_r <= result_valid_r_next;
          result_r <= result_r_next;
       end
    end

    // Wire up the outputs
    assign tuple_out_@EXTERN_NAME@_output_VALID = result_valid_r;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = result_r;

endmodule

