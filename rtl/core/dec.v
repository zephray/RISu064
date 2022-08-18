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

// This module wraps 2 dec_bundled and run them through a 2w2r fifo
module dec(
    input  wire         clk,
    input  wire         rst,
    input  wire         pipe_flush,
    // IF interface
    // dec1 higher address
    input  wire [63:0]  if_dec1_pc,
    input  wire [31:0]  if_dec1_instr,
    input  wire         if_dec1_bp,
    input  wire [1:0]   if_dec1_bp_track,
    input  wire [63:0]  if_dec1_bt,
    input  wire         if_dec1_page_fault,
    input  wire         if_dec1_valid,
    // dec0 lower address
    input  wire [63:0]  if_dec0_pc,
    input  wire [31:0]  if_dec0_instr,
    input  wire         if_dec0_bp,
    input  wire [1:0]   if_dec0_bp_track,
    input  wire [63:0]  if_dec0_bt,
    input  wire         if_dec0_page_fault,
    input  wire         if_dec0_valid,
    output wire         if_dec_ready,
    // IX interface
    output wire [247:0] dec1_ix_bundle,
    output wire         dec1_ix_valid,
    input  wire         dec1_ix_ready,
    output wire [247:0] dec0_ix_bundle,
    output wire         dec0_ix_valid,
    input  wire         dec0_ix_ready
);

    wire [247:0] dec0_bundle;
    wire [247:0] dec1_bundle;

    dec_bundled dec0(
        // IF interface
        .if_dec_pc(if_dec0_pc),
        .if_dec_instr(if_dec0_instr),
        .if_dec_bp(if_dec0_bp),
        .if_dec_bp_track(if_dec0_bp_track),
        .if_dec_bt(if_dec0_bt),
        .if_dec_page_fault(if_dec0_page_fault),
        // IX interface
        .dec_ix_bundle(dec0_bundle)
    );

    dec_bundled dec1(
        // IF interface
        .if_dec_pc(if_dec1_pc),
        .if_dec_instr(if_dec1_instr),
        .if_dec_bp(if_dec1_bp),
        .if_dec_bp_track(if_dec1_bp_track),
        .if_dec_bt(if_dec1_bt),
        .if_dec_page_fault(if_dec1_page_fault),
        // IX interface
        .dec_ix_bundle(dec1_bundle)
    );

    /* verilator lint_off PINMISSING */
    fifo_2w2r #(.WIDTH(248), .ABITS(3), .DEPTH(6)) iq (
        .clk(clk),
        .rst(rst || pipe_flush),
        .a1_data(dec1_bundle),
        .a1_valid(if_dec1_valid),
        .a0_data(dec0_bundle),
        .a0_valid(if_dec0_valid),
        .a_ready(if_dec_ready),
        .b1_data(dec1_ix_bundle),
        .b1_valid(dec1_ix_valid),
        .b1_ready(dec1_ix_ready),
        .b0_data(dec0_ix_bundle),
        .b0_valid(dec0_ix_valid),
        .b0_ready(dec0_ix_ready)
    );
    /* verilator lint_on PINMISSING */

endmodule
