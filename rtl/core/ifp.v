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
    // Exception and CSR induced control flow change are not tracked by BP
    input  wire         ip_if_branch,
    input  wire         ip_if_branch_taken,
    input  wire [63:0]  ip_if_branch_pc,
    input  wire         if_pc_override,
    input  wire [63:0]  if_new_pc
);
    localparam RESET_VECTOR = 64'h0000000080000000;

    // F1: PC generation and Imem request
    wire [63:0] next_pc;
    reg [63:0] f1_f2_pc;
    reg f1_f2_valid;

    wire fifo_bp;
    wire ifp_stalled_memory_resp = (f1_f2_valid && !im_resp_valid) && !rst;
    wire ifp_stalled_back_pressure = (fifo_bp && !if_dec_ready) && !rst;
    wire ifp_stalled = ifp_stalled_memory_resp || ifp_stalled_back_pressure;
    reg ifp_stalled_last;
    wire [63:0] ifp_new_pc;
    wire ifp_pc_override;
    wire ifp_memreq_nack = im_req_valid && !im_req_ready;
    reg ifp_memreq_nack_last;
    reg ifp_memreq_last;

    wire next_valid =
            ((!ifp_stalled && !ifp_stalled_last && !ifp_memreq_nack_last) ||
            ((!ifp_stalled && ifp_stalled_last) || ifp_memreq_nack_last)) && !rst;

    fifo_1d_fwft #(.WIDTH(64)) if_new_pc_buffer(
        .clk(clk),
        .rst(rst),
        .a_data(if_new_pc),
        .a_valid(if_pc_override),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .b_data(ifp_new_pc),
        .b_valid(ifp_pc_override),
        .b_ready(next_valid && !ifp_memreq_nack)
    );

    // BTB
    // Valid PC: [31:2] // 30 bits
    // index: 5 bits, tag: 25 bits, target address: 30 bits, valid 1 bit
    // total: 56 bit
    wire [4:0] btb_index = next_pc[6:2];
    wire [55:0] btb_rd;

    reg btb_init_active = 1'b0;
    reg [4:0] btb_init_index;
    always @(posedge clk) begin
        // BTB initializer
        if (btb_init_active) begin
            if (btb_init_index == 5'd31)
                btb_init_active <= 1'b0;
            btb_init_index <= btb_init_index + 1;
        end
        if (rst) begin
            btb_init_active <= 1'b1;
            btb_init_index <= 5'd0;
        end
    end

    wire [4:0] btb_wr_index = (btb_init_active) ? (btb_init_index) :
            (ip_if_branch_pc[6:2]);
    wire [55:0] btb_wr_data = (btb_init_active) ? (56'd0) :
            ({1'b1, ip_if_branch_pc[31:7], if_new_pc[31:2]});
    wire btb_wr_en = (btb_init_active) ? (1'b1) :
            (ip_if_branch && ip_if_branch_taken);

    /*always @(posedge clk) begin
        if (btb_wr_en) begin
            $display("BTB index %d update to %014x", btb_wr_index, btb_wr_data);
        end
    end*/

    ram_32_56 btb_ram(
        .clk(clk),
        .rst(rst),
        .raddr(btb_index),
        .re(next_valid && !ifp_memreq_nack),
        .rd(btb_rd), // 1 cycle later
        .waddr(btb_wr_index),
        .wr(btb_wr_data),
        .we(btb_wr_en)
    );

    // Placeholder for BPU and BTB. What about RAS
    // TODO: Handle cases where an ifencei or something else happend so the
    // instruction at a certain PC is no longer a branch. This should be
    // corrected somewhere.
    wire bp_result = `BP_TAKEN;
    wire [63:0] btb_result = {32'b0, btb_rd[29:0], 2'b0};
    wire btb_hit = btb_rd[55] && (btb_rd[54:30] == f1_f2_pc[31:7]) && !btb_init_active;
    wire f1_bp = (bp_result == `BP_TAKEN) && (btb_hit);

    /*always @(posedge clk) begin
        if (btb_hit) begin
            $display("BTB PC %08x hit with %014x", f1_f2_pc, btb_rd);
        end
    end*/

    // Exteremely simple BPU

    assign next_pc =
            (ifp_pc_override) ? (ifp_new_pc) : // mis-predict
            (f1_bp) ? (btb_result) : // predicted branch
            (f1_f2_pc + 4); // PC incr

    always @(posedge clk) begin
        // Continue only if pipeline is not stalled
        if (!ifp_stalled_memory_resp) begin
            f1_f2_valid <= im_req_valid && im_req_ready;
        end
        if (next_valid && !ifp_memreq_nack) begin
            f1_f2_pc <= next_pc;
        end

        ifp_memreq_last <= im_req_valid;
        ifp_stalled_last <= ifp_stalled;
        ifp_memreq_nack_last <= ifp_memreq_nack;

        if (rst) begin
            f1_f2_pc <= RESET_VECTOR - 4;
            f1_f2_valid <= 1'b0;
            ifp_stalled_last <= 1'b0;
        end
    end

    assign im_req_valid = next_valid;
    assign im_req_addr = next_pc;

    // F2: Imem result
    wire [31:0] im_instr = (f1_f2_pc[2]) ? im_resp_rdata[63:32] :
            im_resp_rdata[31:0];
    wire if_dec_pc_override;
    wire fifo_valid;

    fifo_2d #(.WIDTH(162)) if_fifo (
        .clk(clk),
        .rst(rst || ifp_pc_override),
        .a_data({im_instr, f1_f2_pc, f1_bp, btb_result, ifp_pc_override}),
        .a_valid(im_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .a_almost_full(fifo_bp),
        .b_data({if_dec_instr, if_dec_pc, if_dec_bp, if_dec_bt, if_dec_pc_override}),
        .b_valid(fifo_valid),
        .b_ready(if_dec_ready)
    );

    /*`ifdef VERBOSE
    always @(posedge clk) begin
        if (if_dec_valid && if_dec_ready) begin
            $display("IF %016x INSTR %08x", if_dec_pc, if_dec_instr);
        end
    end
    `endif*/

    assign if_dec_valid = (if_dec_pc_override) ? 1'b0 : fifo_valid;

endmodule
