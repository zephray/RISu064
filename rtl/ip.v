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
    input  wire [3:0]   ix_ip_op,
    input  wire         ix_ip_option,
    input  wire         ix_ip_truncate,
    input  wire [1:0]   ix_ip_br_type,
    input  wire         ix_ip_br_neg,
    input  wire [63:0]  ix_ip_br_base,
    input  wire [20:0]  ix_ip_br_offset,
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
    output reg          ip_if_pc_override,
    output reg  [63:0]  ip_if_new_pc
);
    parameter IP_HANDLE_BRANCH = 1;

    wire [63:0] alu_result;

    // BT_NONE : PCAdder - do nothing, ALU - normal op
    // BT_JAL  : PCAdder - PC + imm  , ALU - PC + 4
    // BT_JALR : PCAdder - opr1 + imm, ALU - PC + 4
    // BT_BCOND: PCAdder - PC + imm  , ALU - Branch condition

    generate
    if (IP_HANDLE_BRANCH == 1) begin: ip_branch_support
        wire [63:0] br_offset = {{43{ix_ip_br_offset[20]}}, ix_ip_br_offset};
        wire [63:0] br_target = (ix_ip_br_base + br_offset) & (~64'd1);
        wire br_take =
                (ix_ip_br_type == `BT_NONE) ? (1'b0) :
                (ix_ip_br_type == `BT_JAL) ? (1'b1) :
                (ix_ip_br_type == `BT_JALR) ? (1'b1) :
                ((ix_ip_br_neg) ? (!alu_result[0]) : (alu_result[0]));
        // Test if branch prediction is correct or not
        wire br_correct = (br_take == ix_ip_bp) &&
                ((br_take) ? (br_target == ix_ip_bt) : 1'b1);
        wire ip_if_pc_override_comb = (ix_ip_valid) && (ix_ip_br_type != `BT_NONE)
                && (!br_correct);
        wire [63:0] ip_if_new_pc_comb = br_target;
        always @(posedge clk) begin
            ip_if_pc_override <= ip_if_pc_override_comb;
            ip_if_new_pc <= ip_if_new_pc_comb;
        end
    end
    endgenerate

    alu alu(
        .op(ix_ip_op),
        .option(ix_ip_option),
        .operand1(ix_ip_operand1),
        .operand2(ix_ip_operand2),
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
                ip_wb_valid <= ix_ip_valid && !ip_if_pc_override;
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
