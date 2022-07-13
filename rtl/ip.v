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

// Integer pipeline
// Pipeline latency = 1 cycle
module ip(
    input  wire         clk,
    input  wire         rst,
    // From issue
    input  wire [63:0]  ix_ip_pc,
    input  wire [4:0]   ix_ip_dst,
    input  wire         ix_ip_wb_en,
    input  wire [2:0]   ix_ip_op,
    input  wire         ix_ip_option,
    input  wire         ix_ip_truncate,
    input  wire [1:0]   ix_ip_br_type,
    input  wire [20:0]  ix_ip_boffset,
    input  wire [63:0]  ix_ip_operand1,
    input  wire [63:0]  ix_ip_operand2,
    input  wire         ix_ip_bp,
    input  wire [63:0]  ix_ip_bt,
    input  wire         ix_ip_valid,
    output wire         ix_ip_ready,
    // Forwarding path back to issue
    output wire [63:0]  ip_ix_forwarding,
    // To writeback
    output reg  [4:0]   ip_wb_dst,
    output reg  [63:0]  ip_wb_result,
    output reg  [63:0]  ip_wb_pc,
    output reg          ip_wb_wb_en,
    output reg          ip_wb_valid,
    input  wire         ip_wb_ready,
    // To instruction fetch unit
    output wire         ip_if_pc_override,
    output wire [63:0]  ip_if_new_pc
);
    parameter IP_HANDLE_BRANCH = 1;

    wire [63:0] alu_result;
    wire [2:0] alu_op;
    wire alu_option;
    wire [63:0] alu_operand1;
    wire [63:0] alu_operand2;

    // BT_NONE : PCAdder - do nothing, ALU - normal op
    // BT_JAL  : PCAdder - PC + imm  , ALU - Forced PC + 4
    // BT_JALR : PCAdder - PC + opr1 , ALU - Forced PC + 4
    // BT_BCOND: PCAdder - PC + imm  , ALU - Branch condition

    generate
    if (IP_HANDLE_BRANCH == 1) begin: ip_branch_support
        wire br_neg; // Neg: 0 - zero means doesn't jump, 1 - zero means jump
        assign {alu_option, alu_op, br_neg} = (ix_ip_br_type == `BT_BCOND) ? (
                (ix_ip_op == `BC_EQ) ? ({`ALUOPT_SUB, `ALU_ADDSUB, 1'b1}) :
                (ix_ip_op == `BC_NE) ? ({`ALUOPT_SUB, `ALU_ADDSUB, 1'b0}) :
                (ix_ip_op == `BC_LT) ? ({1'b0, `ALU_SLT, 1'b0}) :
                (ix_ip_op == `BC_GE) ? ({1'b0, `ALU_SLT, 1'b1}) :
                (ix_ip_op == `BC_LTU) ? ({1'b0, `ALU_SLTU, 1'b0}) :
                (ix_ip_op == `BC_GEU) ? ({1'b0, `ALU_SLTU, 1'b1}) : 5'bx
                ) : ({ix_ip_option, ix_ip_op, 1'bx});
        assign alu_operand1 =
                ((ix_ip_br_type == `BT_NONE) || (ix_ip_br_type == `BT_BCOND)) ?
                (ix_ip_operand1) : (ix_ip_pc);
        assign alu_operand2 =
                ((ix_ip_br_type == `BT_NONE) || (ix_ip_br_type == `BT_BCOND)) ?
                (ix_ip_operand2) : (64'd4);
        
        wire [63:0] br_offset_sext = {{43{ix_ip_boffset[20]}}, ix_ip_boffset};
        wire [63:0] br_jalr_target =
                {{(ix_ip_operand1 + br_offset_sext)}[63:1], 1'b0};
        wire [63:0] br_target =
                (ix_ip_br_type == `BT_NONE) ? (64'bx) :
                (ix_ip_br_type == `BT_JALR) ? (br_jalr_target) :
                (ix_ip_pc + br_offset_sext);
        wire alu_result_zero = alu_result == 64'b0;
        wire br_take =
                (ix_ip_br_type == `BT_NONE) ? (1'b0) :
                (ix_ip_br_type == `BT_JAL) ? (1'b1) :
                (ix_ip_br_type == `BT_JALR) ? (1'b1) :
                ((br_neg) ? (alu_result_zero) : (!alu_result_zero));
        // Test if branch prediction is correct or not
        wire br_correct = (br_take == ix_ip_bp) &&
                ((br_take) ? (br_target == ix_ip_bt) : 1'b1);
        assign ip_if_pc_override = (ix_ip_valid) && (ix_ip_br_type != `BT_NONE)
                && (!br_correct);
        assign ip_if_new_pc = br_target;
    end
    else begin
        assign alu_op = ix_ip_op;
        assign alu_option = ix_ip_option;
        assign alu_operand1 = ix_ip_operand1;
        assign alu_operand2 = ix_ip_operand2;
    end
    endgenerate

    alu alu(
        .op(alu_op),
        .option(alu_option),
        .operand1(alu_operand1),
        .operand2(alu_operand2),
        .result(alu_result)
    );

    wire [63:0] wb_result = (ix_ip_truncate) ?
                {{32{alu_result[31]}}, alu_result[31:0]} : // 32-bit operation
                alu_result; // 64-bit operation

    assign ip_ix_forwarding = wb_result;

    assign ix_ip_ready = ip_wb_ready;

    always @(posedge clk) begin
        if (rst) begin
            ip_wb_valid <= 1'b0;
        end
        else begin
            if (ix_ip_ready) begin
                ip_wb_valid <= ix_ip_valid;
            end
            else if (ip_wb_ready && ip_wb_valid) begin
                ip_wb_valid <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (ix_ip_ready) begin
            ip_wb_dst <= ix_ip_dst;
            ip_wb_result <= wb_result;
            ip_wb_pc <= ix_ip_pc;
            ip_wb_wb_en <= ix_ip_wb_en;
        end
    end

endmodule
