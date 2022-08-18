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
// This module wraps du module and bundle the output to a wide bit-vector
// without pre-buffering with DFFs. For easier use with FIFOs
module dec_bundled(
    // IF interface
    input  wire [63:0]  if_dec_pc,
    input  wire [31:0]  if_dec_instr,
    input  wire         if_dec_bp,
    input  wire [1:0]   if_dec_bp_track,
    input  wire [63:0]  if_dec_bt,
    input  wire         if_dec_page_fault,
    // IX interface
    output wire [247:0] dec_ix_bundle
);

    wire [3:0]  dec_op;
    wire        dec_option;
    wire        dec_truncate;
    wire [1:0]  dec_br_type;
    wire        dec_br_neg;
    wire        dec_br_base_src;
    wire        dec_br_inj_pc;
    wire        dec_br_is_call;
    wire        dec_br_is_ret;
    wire        dec_mem_sign;
    wire [1:0]  dec_mem_width;
    wire [1:0]  dec_csr_op;
    wire        dec_mret;
    wire        dec_intr;
    wire [3:0]  dec_cause;
    wire [2:0]  dec_md_op;
    wire        dec_muldiv;
    wire [2:0]  dec_op_type;
    wire [1:0]  dec_operand1;
    wire [1:0]  dec_operand2;
    wire [63:0] dec_imm;
    wire        dec_legal;
    wire        dec_wb_en;
    wire [4:0]  dec_rs1;
    wire [4:0]  dec_rs2;
    wire [4:0]  dec_rd;
    wire        dec_fencei;
    du du0(
        .instr(if_dec_instr),
        .page_fault(if_dec_page_fault),
        .op(dec_op),
        .option(dec_option),
        .truncate(dec_truncate),
        .br_type(dec_br_type),
        .br_neg(dec_br_neg),
        .br_base_src(dec_br_base_src),
        .br_inj_pc(dec_br_inj_pc),
        .br_is_call(dec_br_is_call),
        .br_is_ret(dec_br_is_ret),
        .mem_sign(dec_mem_sign),
        .mem_width(dec_mem_width),
        .csr_op(dec_csr_op),
        .mret(dec_mret),
        .intr(dec_intr),
        .cause(dec_cause),
        .md_op(dec_md_op),
        .muldiv(dec_muldiv),
        .op_type(dec_op_type),
        .operand1(dec_operand1),
        .operand2(dec_operand2),
        .imm(dec_imm),
        .legal(dec_legal),
        .wb_en(dec_wb_en),
        .rs1(dec_rs1),
        .rs2(dec_rs2),
        .rd(dec_rd),
        .fencei(dec_fencei)
    );

    assign dec_ix_bundle = {
        if_dec_pc,
        if_dec_bp,
        if_dec_bp_track,
        if_dec_bt,
        dec_op,
        dec_option,
        dec_truncate,
        dec_br_type,
        dec_br_neg,
        dec_br_base_src,
        dec_br_inj_pc,
        dec_br_is_call,
        dec_br_is_ret,
        dec_mem_sign,
        dec_mem_width,
        dec_csr_op,
        dec_mret,
        dec_intr,
        dec_cause,
        dec_md_op,
        dec_muldiv,
        dec_op_type,
        dec_operand1,
        dec_operand2,
        dec_imm,
        dec_legal,
        dec_wb_en,
        dec_rs1,
        dec_rs2,
        dec_rd,
        dec_fencei};

endmodule
