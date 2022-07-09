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
    // From decoder
    input  wire [63:0]  ix_ip_pc,
    input  wire [4:0]   ix_ip_dst,
    input  wire         ix_ip_wb_en,
    input  wire [2:0]   ix_ip_op,
    input  wire         ix_ip_option,
    input  wire         ix_ip_truncate,
    input  wire [63:0]  ix_ip_operand1,
    input  wire [63:0]  ix_ip_operand2,
    input  wire         ix_ip_valid,
    output wire         ix_ip_ready,
    // To writeback
    output reg [4:0]    ip_ix_dst,
    output reg [63:0]   ip_ix_result,
    output reg [63:0]   ip_ix_pc,
    output reg          ip_ix_wb_en,
    output reg          ip_ix_valid,
    input  wire         ip_ix_ready
);
    wire [63:0] alu_result;

    alu alu(
        .op(ix_ip_op),
        .option(ix_ip_option),
        .operand1(ix_ip_operand1),
        .operand2(ix_ip_operand2),
        .result(alu_result)
    );

    wire ix_stalled = ip_ix_valid && !ip_ix_ready;
    assign ix_ip_ready = !ix_stalled;

    always @(posedge clk) begin
        if (rst) begin
            ip_ix_valid <= 1'b0;
        end
        else begin
            ip_ix_valid <= ix_ip_valid;
        end
    end

    always @(posedge clk) begin
        ip_ix_dst <= ix_ip_dst;
        ip_ix_result <= (ix_ip_truncate) ?
            {{32{alu_result[31]}}, alu_result[31:0]} :
            alu_result;
        ip_ix_pc <= ix_ip_pc;
        ip_ix_wb_en <= ix_ip_wb_en;
    end

endmodule
