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
    // IF interface
    input  wire [63:0]  if_dec_pc,
    input  wire [31:0]  if_dec_instr,
    input  wire         if_dec_valid,
    output wire         if_dec_ready,
    // IX interface
    output reg  [63:0]  dec_ix_pc,
    output reg  [2:0]   dec_ix_op,
    output reg          dec_ix_option,
    output reg          dec_ix_truncate,
    output reg          dec_ix_mem_sign,
    output reg  [1:0]   dec_ix_mem_width,
    output reg  [1:0]   dec_ix_operand1,
    output reg  [1:0]   dec_ix_operand2,
    output reg  [63:0]  dec_ix_imm,
    output reg  [2:0]   dec_ix_op_type,
    output reg          dec_ix_legal,
    output reg          dec_ix_wb_en,
    output reg  [4:0]   dec_ix_rs1,
    output reg  [4:0]   dec_ix_rs2,
    output reg  [4:0]   dec_ix_rd,
    output reg          dec_ix_valid,
    input  wire         dec_ix_ready
);

    wire [2:0] dec_op;
    wire dec_option;
    wire dec_truncate;
    wire dec_mem_sign;
    wire [1:0] dec_mem_width;
    wire [1:0] dec_operand1;
    wire [1:0] dec_operand2;
    wire [63:0] dec_imm;
    wire [2:0] dec_op_type;
    wire dec_legal;
    wire dec_wb_en;
    wire [4:0] dec_rs1;
    wire [4:0] dec_rs2;
    wire [4:0] dec_rd;
    du du0(
        .instr(if_dec_instr),
        .op(dec_op),
        .option(dec_option),
        .truncate(dec_truncate),
        .mem_sign(dec_mem_sign),
        .mem_width(dec_mem_width),
        .op_type(dec_op_type),
        .operand1(dec_operand1),
        .operand2(dec_operand2),
        .imm(dec_imm),
        .legal(dec_legal),
        .wb_en(dec_wb_en),
        .rs1(dec_rs1),
        .rs2(dec_rs2),
        .rd(dec_rd)
    );

    always @(posedge clk) begin
        if (rst) begin
            dec_ix_valid <= 1'b0;
        end
        else begin
            dec_ix_valid <= if_dec_valid;
        end
    end

    always @(posedge clk) begin
        if (if_dec_ready) begin
            dec_ix_pc <= if_dec_pc;
            dec_ix_op <= dec_op;
            dec_ix_option <= dec_option;
            dec_ix_truncate <= dec_truncate;
            dec_ix_mem_sign <= dec_mem_sign;
            dec_ix_mem_width <= dec_mem_width;
            dec_ix_operand1 <= dec_operand1;
            dec_ix_operand2 <= dec_operand2;
            dec_ix_imm <= dec_imm;
            dec_ix_op_type <= dec_op_type;
            dec_ix_legal <= dec_legal;
            dec_ix_wb_en <= dec_wb_en;
            dec_ix_rs1 <= dec_rs1;
            dec_ix_rs2 <= dec_rs2;
            dec_ix_rd <= dec_rd;
        end
    end

    assign if_dec_ready = dec_ix_ready;

endmodule