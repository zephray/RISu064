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

// Instruction fetching pipeline
// Pipeline latency = 2 cycles: PCgen, Imem
module ifp(
    input  wire         clk,
    input  wire         rst,
    // I-mem interface
    output wire [63:0]  im_req_addr,
    output wire         im_req_valid,
    input  wire         im_req_ready,
    input  wire [63:0]  im_resp_rdata,
    input  wire         im_resp_valid,
    // Decoder interface
    output wire [63:0]  if_dec_pc,
    output wire [31:0]  if_dec_instr,
    output wire         if_dec_bp,
    output wire [63:0]  if_dec_bt,
    output wire         if_dec_valid,
    input  wire         if_dec_ready,
    // Next PC
    input  wire         ip_if_pc_override,
    input  wire [63:0]  ip_if_new_pc
);
    localparam RESET_VECTOR = 64'h0000000080000000;

    // F1: PC generation
    wire [63:0] next_pc;
    reg [63:0] f1_f2_pc;
    reg f1_f2_bp;
    reg [63:0] f1_f2_bt;
    reg f1_f2_valid;

    // Placeholder for BPU and BTB. What about RAS
    wire bp_result = `BP_NOT_TAKEN;
    wire [63:0] btb_result = 64'bx;

    wire ifp_stalled_memory_resp = (f2_dec_req_valid && !im_resp_valid) && !rst;
    wire ifp_stalled_memory_req = (!ifp_memreq_fifo_ready) && !rst;
    wire ifp_stalled_back_pressure = (!if_dec_ready) && !rst;
    wire ifp_stalled = ifp_stalled_memory_resp || ifp_stalled_memory_req ||
            ifp_stalled_back_pressure;
    reg ifp_stalled_last;
    wire [63:0] if_new_pc;
    wire if_pc_override;

    fifo_1d_fwft #(.WIDTH(64)) if_new_pc_buffer(
        .clk(clk),
        .rst(rst),
        .a_data(ip_if_new_pc),
        .a_valid(ip_if_pc_override),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .b_data(if_new_pc),
        .b_valid(if_pc_override),
        .b_ready(!(ifp_stalled || ifp_stalled_last))
    );

    assign next_pc =
            (if_pc_override) ? (if_new_pc) :
            (bp_result == `BP_TAKEN) ? (btb_result) : // Branch
            (f1_f2_pc + 4); // PC incr

    always @(posedge clk) begin
        if (rst) begin
            f1_f2_pc <= RESET_VECTOR - 4;
            f1_f2_valid <= 1'b0;
            ifp_stalled_last <= 1'b0;
        end
        else begin
            // Continue only if pipeline is not stalled
            if (!ifp_stalled && !ifp_stalled_last) begin
                f1_f2_valid <= 1'b1;
                f1_f2_pc <= next_pc;
                f1_f2_bp <= bp_result;
                f1_f2_bt <= btb_result;
            end
            else begin
                if (!ifp_stalled && ifp_stalled_last)
                    f1_f2_valid <= 1'b1;
                else
                    f1_f2_valid <= 1'b0;
            end
            ifp_stalled_last <= ifp_stalled;
        end
    end

    // F2: I mem
    reg f2_dec_pc_override;
    reg [63:0] f2_dec_pc;
    reg f2_dec_bp;
    reg [63:0] f2_dec_bt;
    reg f2_dec_req_valid;

    always @(posedge clk) begin
        if (!ifp_stalled_memory_resp) begin
            f2_dec_req_valid <= im_req_valid;
        end
        if (!ifp_stalled) begin
            f2_dec_pc <= f1_f2_pc;
            f2_dec_bp <= f1_f2_bp;
            f2_dec_bt <= f1_f2_bt;
            f2_dec_pc_override <= if_pc_override;
        end
    end

    wire ifp_memreq_fifo_ready;
    fifo_1d_fwft #(.WIDTH(64)) ifp_memreq_fifo (
        .clk(clk),
        .rst(rst),
        .a_data(f1_f2_pc),
        .a_valid(f1_f2_valid && !ifp_stalled),
        .a_ready(ifp_memreq_fifo_ready),
        .b_data(im_req_addr),
        .b_valid(im_req_valid),
        .b_ready(im_req_ready)
    );

    wire [31:0] im_instr = (f2_dec_pc[2]) ? im_resp_rdata[63:32] :
            im_resp_rdata[31:0];

    // Output buffering
    wire fifo_valid;
    wire if_dec_pc_override;
    wire if_dec_pc_override_late;
    fifo_2d_fwft #(.WIDTH(163)) if_fifo (
        .clk(clk),
        .rst(rst),
        .a_data({im_instr, f2_dec_pc, f2_dec_bp, f2_dec_bt, f2_dec_pc_override, if_pc_override}),
        .a_valid(im_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .b_data({if_dec_instr, if_dec_pc, if_dec_bp, if_dec_bt, if_dec_pc_override, if_dec_pc_override_late}),
        .b_valid(fifo_valid),
        .b_ready(if_dec_ready)
    );

    assign if_dec_valid = (if_dec_pc_override || if_dec_pc_override_late) ? 1'b0 : fifo_valid;

endmodule
