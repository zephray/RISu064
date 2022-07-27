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

// This module wraps one or more combinational decoder units and wrap it with
// pipeline registers
module dec(
    input  wire         clk,
    input  wire         rst,
    input  wire         pipe_flush,
    // IF interface
    input  wire [63:0]  if_dec_pc,
    input  wire [31:0]  if_dec_instr,
    input  wire         if_dec_bp,
    input  wire [63:0]  if_dec_bt,
    input  wire         if_dec_valid,
    output wire         if_dec_ready,
    // IX interface
    output reg  [63:0]  dec_ix_pc,
    output reg          dec_ix_bp,
    output reg  [63:0]  dec_ix_bt,
    output reg  [3:0]   dec_ix_op,
    output reg          dec_ix_option,
    output reg          dec_ix_truncate,
    output reg  [1:0]   dec_ix_br_type,
    output reg          dec_ix_br_neg,
    output reg          dec_ix_br_base_src,
    output reg          dec_ix_br_inj_pc,
    output reg          dec_ix_mem_sign,
    output reg  [1:0]   dec_ix_mem_width,
    output reg  [1:0]   dec_ix_csr_op,
    output reg          dec_ix_mret,
    output reg          dec_ix_intr,
    output reg  [3:0]   dec_ix_cause,
    output reg  [2:0]   dec_ix_md_op,
    output reg          dec_ix_muldiv,
    output reg  [2:0]   dec_ix_op_type,
    output reg  [1:0]   dec_ix_operand1,
    output reg  [1:0]   dec_ix_operand2,
    output reg  [63:0]  dec_ix_imm,
    output reg          dec_ix_legal,
    output reg          dec_ix_wb_en,
    output reg  [4:0]   dec_ix_rs1,
    output reg  [4:0]   dec_ix_rs2,
    output reg  [4:0]   dec_ix_rd,
    output reg          dec_ix_fencei,
    output reg          dec_ix_valid,
    input  wire         dec_ix_ready
);

    wire [3:0] dec_op;
    wire dec_option;
    wire dec_truncate;
    wire [1:0] dec_br_type;
    wire dec_br_neg;
    wire dec_br_base_src;
    wire dec_br_inj_pc;
    wire dec_mem_sign;
    wire [1:0] dec_mem_width;
    wire [1:0] dec_csr_op;
    wire dec_mret;
    wire dec_intr;
    wire [3:0] dec_cause;
    wire [2:0] dec_md_op;
    wire dec_muldiv;
    wire [2:0] dec_op_type;
    wire [1:0] dec_operand1;
    wire [1:0] dec_operand2;
    wire [63:0] dec_imm;
    wire dec_legal;
    wire dec_wb_en;
    wire [4:0] dec_rs1;
    wire [4:0] dec_rs2;
    wire [4:0] dec_rd;
    wire dec_fencei;
    du du0(
        .instr(if_dec_instr),
        .op(dec_op),
        .option(dec_option),
        .truncate(dec_truncate),
        .br_type(dec_br_type),
        .br_neg(dec_br_neg),
        .br_base_src(dec_br_base_src),
        .br_inj_pc(dec_br_inj_pc),
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

    always @(posedge clk) begin
        if (rst) begin
            dec_ix_valid <= 1'b0;
        end
        else begin
            if (pipe_flush) begin
                dec_ix_valid <= 1'b0;
            end
            else if (if_dec_ready) begin
                dec_ix_valid <= if_dec_valid;
            end
        end
    end

    always @(posedge clk) begin
        if (if_dec_ready) begin
            dec_ix_pc <= if_dec_pc;
            dec_ix_bp <= if_dec_bp;
            dec_ix_bt <= if_dec_bt;
            dec_ix_op <= dec_op;
            dec_ix_option <= dec_option;
            dec_ix_truncate <= dec_truncate;
            dec_ix_br_type <= dec_br_type;
            dec_ix_br_neg <= dec_br_neg;
            dec_ix_br_base_src <= dec_br_base_src;
            dec_ix_br_inj_pc <= dec_br_inj_pc;
            dec_ix_mem_sign <= dec_mem_sign;
            dec_ix_mem_width <= dec_mem_width;
            dec_ix_csr_op <= dec_csr_op;
            dec_ix_mret <= dec_mret;
            dec_ix_intr <= dec_intr;
            dec_ix_cause <= dec_cause;
            dec_ix_md_op <= dec_md_op;
            dec_ix_muldiv <= dec_muldiv;
            dec_ix_op_type <= dec_op_type;
            dec_ix_operand1 <= dec_operand1;
            dec_ix_operand2 <= dec_operand2;
            dec_ix_imm <= dec_imm;
            dec_ix_legal <= dec_legal;
            dec_ix_wb_en <= dec_wb_en;
            dec_ix_rs1 <= dec_rs1;
            dec_ix_rs2 <= dec_rs2;
            dec_ix_rd <= dec_rd;
            dec_ix_fencei <= dec_fencei;
        end
    end

    assign if_dec_ready = dec_ix_ready;

endmodule
