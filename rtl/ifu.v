`timescale 1ns / 1ps
`default_nettype none
//
// RISu64
// Copyright 2022 Wenting Zhang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
`include "defines.vh"

// Instruction fetching unit
module ifu(
    input  wire         clk,
    input  wire         rst,
    // I-mem interface
    output wire [63:0] im_req_addr,
    output wire        im_req_valid,
    input  wire [63:0] im_resp_rdata,
    input  wire        im_resp_valid,
    // Decoder interface
    output wire [63:0] if_dec_pc,
    output wire [31:0] if_dec_instr,
    output reg         if_dec_valid,
    input  wire        if_dec_ready
);
    localparam RESET_VECTOR = 64'h0000000010000000;

    wire [63:0] next_pc;
    reg [63:0] if_pc;

    always @(posedge clk) begin
        if (rst) begin
            if_pc <= RESET_VECTOR - 4;
        end
        else begin
            if_pc <= next_pc;
        end
    end

    // Continue only if dec is ready
    assign next_pc = (if_dec_ready) ? if_pc + 4 : if_pc;

    assign im_req_addr = next_pc;
    assign im_req_valid = if_dec_ready;

    wire [31:0] im_instr = (if_pc[2]) ? im_resp_rdata[63:32] : im_resp_rdata[31:0];

    fifo_1d_fwft #(.WIDTH(32)) if_fifo(
        .clk(clk),
        .rst(rst),
        .a_data(im_instr),
        .a_valid(im_resp_valid),
        .a_ready(),
        .b_data(if_dec_instr),
        .b_valid(if_dec_valid),
        .b_ready(if_dec_ready)
    );
    assign if_dec_pc = if_pc;

endmodule
