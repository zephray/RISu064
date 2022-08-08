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
// Vivado doesn't allow array inside module ports, so all decoding signals
// has to be duplicated

module cpu(
    input  wire         clk,
    input  wire         rst,
    // Instruction memory
    output wire [63:0]  im_req_addr,
    output wire         im_req_valid,
    input  wire         im_req_ready,
    input  wire [63:0]  im_resp_rdata,
    input  wire         im_resp_valid,
    output wire         im_invalidate_req,
    input  wire         im_invalidate_resp,
    // Data memory
    output wire [63:0]  dm_req_addr,
    output wire [63:0]  dm_req_wdata,
    output wire [7:0]   dm_req_wmask,
    output wire         dm_req_wen,
    output wire         dm_req_valid,
    input  wire         dm_req_ready,
    input  wire [63:0]  dm_resp_rdata,
    input  wire         dm_resp_valid,
    output wire         dm_flush_req,
    input  wire         dm_flush_resp,
    // From CLINT
    input  wire         extint_software,
    input  wire         extint_timer,
    // From PLIC
    input  wire         extint_external
);
    parameter HARTID = 64'd0;

    // Unaligned LS
    wire        lsp_unaligned_load;
    wire        lsp_unaligned_store;
    wire [63:0] lsp_unaligned_epc;

    // Register file
    wire [4:0]  rf_rsrc0;
    wire [63:0] rf_rdata0;
    wire [4:0]  rf_rsrc1;
    wire [63:0] rf_rdata1;
    wire [4:0]  rf_rsrc2;
    wire [63:0] rf_rdata2;
    wire [4:0]  rf_rsrc3;
    wire [63:0] rf_rdata3;
    wire        rf_wen0;
    wire [4:0]  rf_wdst0;
    wire [63:0] rf_wdata0;
    wire        rf_wen1;
    wire [4:0]  rf_wdst1;
    wire [63:0] rf_wdata1;

    rf rf(
        .clk(clk),
        .rst(rst),
        .rf_rsrc0(rf_rsrc0),
        .rf_rdata0(rf_rdata0),
        .rf_rsrc1(rf_rsrc1),
        .rf_rdata1(rf_rdata1),
        .rf_rsrc2(rf_rsrc2),
        .rf_rdata2(rf_rdata2),
        .rf_rsrc3(rf_rsrc3),
        .rf_rdata3(rf_rdata3),
        .rf_wen0(rf_wen0),
        .rf_wdst0(rf_wdst0),
        .rf_wdata0(rf_wdata0),
        .rf_wen1(rf_wen1),
        .rf_wdst1(rf_wdst1),
        .rf_wdata1(rf_wdata1)
    );

    // IF stage
    wire [63:0] if_dec1_pc;
    wire [31:0] if_dec1_instr;
    wire        if_dec1_bp;
    wire [1:0]  if_dec1_bp_track;
    wire [63:0] if_dec1_bt;
    wire        if_dec1_valid;
    wire [63:0] if_dec0_pc;
    wire [31:0] if_dec0_instr;
    wire        if_dec0_bp;
    wire [1:0]  if_dec0_bp_track;
    wire [63:0] if_dec0_bt;
    wire        if_dec0_valid;
    wire        if_dec_ready;
    wire        ip_if_branch;
    wire        ip_if_branch_taken;
    wire [63:0] ip_if_branch_pc;
    wire        ip_if_branch_is_call;
    wire        ip_if_branch_is_ret;
    wire [1:0]  ip_if_branch_track;
    wire        ip_if_pc_override;
    wire [63:0] ip_if_new_pc;
    wire        ix_if_pc_override;
    wire [63:0] ix_if_new_pc;
    wire        trap_if_pc_override;
    wire [63:0] trap_if_new_pc;
    wire        if_pc_override;
    wire [63:0] if_new_pc;
    wire        pipe_flush;

    assign if_pc_override = ip_if_pc_override || ix_if_pc_override ||
            trap_if_pc_override;
    assign if_new_pc = trap_if_pc_override ? trap_if_new_pc :
            ix_if_pc_override ? ix_if_new_pc : ip_if_new_pc;
    assign pipe_flush = if_pc_override || lsp_unaligned_load ||
            lsp_unaligned_store;

    ifp ifp (
        .clk(clk),
        .rst(rst),
        // I-mem interface
        .im_req_addr(im_req_addr),
        .im_req_valid(im_req_valid),
        .im_req_ready(im_req_ready),
        .im_resp_rdata(im_resp_rdata),
        .im_resp_valid(im_resp_valid),
        // Decoder interface
        .if_dec1_pc(if_dec1_pc),
        .if_dec1_instr(if_dec1_instr),
        .if_dec1_bp(if_dec1_bp),
        .if_dec1_bp_track(if_dec1_bp_track),
        .if_dec1_bt(if_dec1_bt),
        .if_dec1_valid(if_dec1_valid),
        .if_dec0_pc(if_dec0_pc),
        .if_dec0_instr(if_dec0_instr),
        .if_dec0_bp(if_dec0_bp),
        .if_dec0_bp_track(if_dec0_bp_track),
        .if_dec0_bt(if_dec0_bt),
        .if_dec0_valid(if_dec0_valid),
        .if_dec_ready(if_dec_ready),
        // Next PC
        .ip_if_branch(ip_if_branch),
        .ip_if_branch_taken(ip_if_branch_taken),
        .ip_if_branch_pc(ip_if_branch_pc),
        .ip_if_branch_is_call(ip_if_branch_is_call),
        .ip_if_branch_is_ret(ip_if_branch_is_ret),
        .ip_if_branch_track(ip_if_branch_track),
        .if_pc_override(if_pc_override),
        .if_new_pc(if_new_pc)
    );

    // Decode stage
    wire [247:0] dec1_ix_bundle;
    wire         dec1_ix_valid;
    wire         dec1_ix_ready;
    wire [247:0] dec0_ix_bundle;
    wire         dec0_ix_valid;
    wire         dec0_ix_ready;
    dec dec(
        .clk(clk),
        .rst(rst),
        .pipe_flush(pipe_flush),
        .if_dec1_pc(if_dec1_pc),
        .if_dec1_instr(if_dec1_instr),
        .if_dec1_bp(if_dec1_bp),
        .if_dec1_bp_track(if_dec1_bp_track),
        .if_dec1_bt(if_dec1_bt),
        .if_dec1_valid(if_dec1_valid),
        .if_dec0_pc(if_dec0_pc),
        .if_dec0_instr(if_dec0_instr),
        .if_dec0_bp(if_dec0_bp),
        .if_dec0_bp_track(if_dec0_bp_track),
        .if_dec0_bt(if_dec0_bt),
        .if_dec0_valid(if_dec0_valid),
        .if_dec_ready(if_dec_ready),
        .dec1_ix_bundle(dec1_ix_bundle),
        .dec1_ix_valid(dec1_ix_valid),
        .dec1_ix_ready(dec1_ix_ready),
        .dec0_ix_bundle(dec0_ix_bundle),
        .dec0_ix_valid(dec0_ix_valid),
        .dec0_ix_ready(dec0_ix_ready)
    );

    // Issue and writeback stage
    wire [63:0] ix_ip0_pc;
    wire [4:0]  ix_ip0_dst;
    wire        ix_ip0_wb_en;
    wire [3:0]  ix_ip0_op;
    wire        ix_ip0_option;
    wire        ix_ip0_truncate;
    wire [1:0]  ix_ip0_br_type;
    wire        ix_ip0_br_neg;
    wire [63:0] ix_ip0_br_base;
    wire [20:0] ix_ip0_br_offset;
    wire        ix_ip0_br_is_call;
    wire        ix_ip0_br_is_ret;
    wire [63:0] ix_ip0_operand1;
    wire [63:0] ix_ip0_operand2;
    wire        ix_ip0_bp;
    wire [1:0]  ix_ip0_bp_track;
    wire [63:0] ix_ip0_bt;
    wire        ix_ip0_valid;
    wire        ix_ip0_ready;
    wire [63:0] ix_ip1_pc;
    wire [4:0]  ix_ip1_dst;
    wire        ix_ip1_wb_en;
    wire [3:0]  ix_ip1_op;
    wire        ix_ip1_option;
    wire        ix_ip1_truncate;
    wire [1:0]  ix_ip1_br_type;
    wire        ix_ip1_br_neg;
    wire [63:0] ix_ip1_br_base;
    wire [20:0] ix_ip1_br_offset;
    wire        ix_ip1_br_is_call;
    wire        ix_ip1_br_is_ret;
    wire [63:0] ix_ip1_operand1;
    wire [63:0] ix_ip1_operand2;
    wire        ix_ip1_bp;
    wire [1:0]  ix_ip1_bp_track;
    wire [63:0] ix_ip1_bt;
    wire        ix_ip1_speculate;
    wire        ix_ip1_valid;
    wire        ix_ip1_ready;
    wire [63:0] ip0_ix_forwarding;
    wire [4:0]  ip0_wb_dst;
    wire [63:0] ip0_wb_result;
    wire        ip0_wb_wb_en;
    wire        ip0_wb_valid;
    wire [63:0] ip1_ix_forwarding;
    wire [4:0]  ip1_wb_dst;
    wire [63:0] ip1_wb_result;
    wire        ip1_wb_wb_en;
    wire        ip1_wb_valid;
    wire [63:0] ix_lsp_pc;
    wire [4:0]  ix_lsp_dst;
    wire        ix_lsp_wb_en;
    wire [63:0] ix_lsp_base;
    wire [11:0] ix_lsp_offset;
    wire [63:0] ix_lsp_source;
    wire        ix_lsp_mem_sign;
    wire [1:0]  ix_lsp_mem_width;
    wire        ix_lsp_speculate;
    wire        ix_lsp_valid;
    wire        ix_lsp_ready;
    wire        lsp_ix_mem_busy;
    wire        lsp_ix_mem_wb_en;
    wire [4:0]  lsp_ix_mem_dst;
    wire        lsp_ix_mem_result_valid;
    wire [63:0] lsp_ix_mem_result;
    wire [4:0]  lsp_wb_dst;
    wire [63:0] lsp_wb_result;
    wire [63:0] lsp_wb_pc;
    wire        lsp_wb_wb_en;
    wire        lsp_wb_valid;
    wire        lsp_wb_ready;
    wire [63:0] ix_md_pc;
    wire [4:0]  ix_md_dst;
    wire [63:0] ix_md_operand1;
    wire [63:0] ix_md_operand2;
    wire [2:0]  ix_md_md_op;
    wire        ix_md_muldiv;
    wire        ix_md_speculate;
    wire        ix_md_valid;
    wire        ix_md_ready;
    wire [4:0]  md_ix_dst;
    wire        md_ix_active;
    wire [63:0] ix_trap_pc;
    wire [4:0]  ix_trap_dst;
    wire [1:0]  ix_trap_csr_op;
    wire [11:0] ix_trap_csr_id;
    wire [63:0] ix_trap_csr_opr;
    wire        ix_trap_mret;
    wire        ix_trap_int;
    wire        ix_trap_intexc;
    wire [3:0]  ix_trap_cause;
    wire        ix_trap_valid;
    wire        ix_trap_ready;
    wire [15:0] trap_ix_ip;
    wire [63:0] wb_ix_buf_value;
    wire [4:0]  wb_ix_buf_dst;
    wire        wb_ix_buf_valid;
    ix ix(
        .clk(clk),
        .rst(rst),
        .pipe_flush(pipe_flush),
        // Register file interface
        .rf_rsrc0(rf_rsrc0),
        .rf_rdata0(rf_rdata0),
        .rf_rsrc1(rf_rsrc1),
        .rf_rdata1(rf_rdata1),
        .rf_rsrc2(rf_rsrc2),
        .rf_rdata2(rf_rdata2),
        .rf_rsrc3(rf_rsrc3),
        .rf_rdata3(rf_rdata3),
        // IX interface
        .dec0_ix_bundle(dec0_ix_bundle),
        .dec0_ix_valid(dec0_ix_valid),
        .dec0_ix_ready(dec0_ix_ready),
        .dec1_ix_bundle(dec1_ix_bundle),
        .dec1_ix_valid(dec1_ix_valid),
        .dec1_ix_ready(dec1_ix_ready),
        // FU interfaces
        // To integer pipe
        .ix_ip0_pc(ix_ip0_pc),
        .ix_ip0_dst(ix_ip0_dst),
        .ix_ip0_wb_en(ix_ip0_wb_en),
        .ix_ip0_op(ix_ip0_op),
        .ix_ip0_option(ix_ip0_option),
        .ix_ip0_truncate(ix_ip0_truncate),
        .ix_ip0_br_type(ix_ip0_br_type),
        .ix_ip0_br_neg(ix_ip0_br_neg),
        .ix_ip0_br_base(ix_ip0_br_base),
        .ix_ip0_br_offset(ix_ip0_br_offset),
        .ix_ip0_br_is_call(ix_ip0_br_is_call),
        .ix_ip0_br_is_ret(ix_ip0_br_is_ret),
        .ix_ip0_operand1(ix_ip0_operand1),
        .ix_ip0_operand2(ix_ip0_operand2),
        .ix_ip0_bp(ix_ip0_bp),
        .ix_ip0_bp_track(ix_ip0_bp_track),
        .ix_ip0_bt(ix_ip0_bt),
        .ix_ip0_valid(ix_ip0_valid),
        .ix_ip0_ready(ix_ip0_ready),
        // Hazard detection & Bypassing
        .ip0_ix_forwarding(ip0_ix_forwarding),
        .ip0_wb_dst(ip0_wb_dst),
        .ip0_wb_result(ip0_wb_result),
        .ip0_wb_wb_en(ip0_wb_wb_en),
        .ip0_wb_valid(ip0_wb_valid),
        // To integer pipe 1
        .ix_ip1_pc(ix_ip1_pc),
        .ix_ip1_dst(ix_ip1_dst),
        .ix_ip1_wb_en(ix_ip1_wb_en),
        .ix_ip1_op(ix_ip1_op),
        .ix_ip1_option(ix_ip1_option),
        .ix_ip1_truncate(ix_ip1_truncate),
        .ix_ip1_br_type(ix_ip1_br_type),
        .ix_ip1_br_neg(ix_ip1_br_neg),
        .ix_ip1_br_base(ix_ip1_br_base),
        .ix_ip1_br_offset(ix_ip1_br_offset),
        .ix_ip1_br_is_call(ix_ip1_br_is_call),
        .ix_ip1_br_is_ret(ix_ip1_br_is_ret),
        .ix_ip1_operand1(ix_ip1_operand1),
        .ix_ip1_operand2(ix_ip1_operand2),
        .ix_ip1_bp(ix_ip1_bp),
        .ix_ip1_bp_track(ix_ip1_bp_track),
        .ix_ip1_bt(ix_ip1_bt),
        .ix_ip1_speculate(ix_ip1_speculate),
        .ix_ip1_valid(ix_ip1_valid),
        .ix_ip1_ready(ix_ip1_ready),
        // Hazard detection & Bypassing
        .ip1_ix_forwarding(ip1_ix_forwarding),
        .ip1_wb_dst(ip1_wb_dst),
        .ip1_wb_result(ip1_wb_result),
        .ip1_wb_wb_en(ip1_wb_wb_en),
        .ip1_wb_valid(ip1_wb_valid),
        // To load/ store pipe
        .ix_lsp_pc(ix_lsp_pc),
        .ix_lsp_dst(ix_lsp_dst),
        .ix_lsp_wb_en(ix_lsp_wb_en),
        .ix_lsp_base(ix_lsp_base),
        .ix_lsp_offset(ix_lsp_offset),
        .ix_lsp_source(ix_lsp_source),
        .ix_lsp_mem_sign(ix_lsp_mem_sign),
        .ix_lsp_mem_width(ix_lsp_mem_width),
        .ix_lsp_speculate(ix_lsp_speculate),
        .ix_lsp_valid(ix_lsp_valid),
        .ix_lsp_ready(ix_lsp_ready),
        .lsp_unaligned_load(lsp_unaligned_load),
        .lsp_unaligned_store(lsp_unaligned_store),
        .lsp_unaligned_epc(lsp_unaligned_epc),
         // Hazard detection & Bypassing
        .lsp_ix_mem_busy(lsp_ix_mem_busy),
        .lsp_ix_mem_wb_en(lsp_ix_mem_wb_en),
        .lsp_ix_mem_dst(lsp_ix_mem_dst),
        .lsp_ix_mem_result(lsp_ix_mem_result),
        .lsp_ix_mem_result_valid(lsp_ix_mem_result_valid),
        .lsp_wb_dst(lsp_wb_dst),
        .lsp_wb_result(lsp_wb_result),
        .lsp_wb_wb_en(lsp_wb_wb_en),
        .lsp_wb_valid(lsp_wb_valid),
        // To muldiv unit
        .ix_md_pc(ix_md_pc),
        .ix_md_dst(ix_md_dst),
        .ix_md_operand1(ix_md_operand1),
        .ix_md_operand2(ix_md_operand2),
        .ix_md_md_op(ix_md_md_op),
        .ix_md_muldiv(ix_md_muldiv),
        .ix_md_speculate(ix_md_speculate),
        .ix_md_valid(ix_md_valid),
        .ix_md_ready(ix_md_ready),
        // Hazard detection
        .md_ix_dst(md_ix_dst),
        .md_ix_active(md_ix_active),
        // To trap unit
        .ix_trap_pc(ix_trap_pc),
        .ix_trap_dst(ix_trap_dst),
        .ix_trap_csr_op(ix_trap_csr_op),
        .ix_trap_csr_id(ix_trap_csr_id),
        .ix_trap_csr_opr(ix_trap_csr_opr),
        .ix_trap_mret(ix_trap_mret),
        .ix_trap_int(ix_trap_int),
        .ix_trap_intexc(ix_trap_intexc),
        .ix_trap_cause(ix_trap_cause),
        .ix_trap_valid(ix_trap_valid),
        .ix_trap_ready(ix_trap_ready),
        .trap_ix_ip(trap_ix_ip),
        // From WB unit
        .wb_ix_buf_value(wb_ix_buf_value),
        .wb_ix_buf_dst(wb_ix_buf_dst),
        .wb_ix_buf_valid(wb_ix_buf_valid),
        // Fence I
        .im_invalidate_req(im_invalidate_req),
        .im_invalidate_resp(im_invalidate_resp),
        .dm_flush_req(dm_flush_req),
        .dm_flush_resp(dm_flush_resp),
        .ix_if_pc_override(ix_if_pc_override),
        .ix_if_new_pc(ix_if_new_pc)
    );

    wire [63:0] ip0_wb_pc;
    wire ip0_wb_ready;
    wire ip0_wb_hipri;
    wire ip0_if_branch;
    wire ip0_if_branch_taken;
    wire [63:0] ip0_if_branch_pc;
    wire ip0_if_branch_is_call;
    wire ip0_if_branch_is_ret;
    wire [1:0] ip0_if_branch_track;
    wire ip0_if_pc_override;
    wire [63:0] ip0_if_new_pc;
    ip #(.IP_HANDLE_BRANCH(1)) ip0(
        .clk(clk),
        .rst(rst),
        // From issue
        .ix_ip_pc(ix_ip0_pc),
        .ix_ip_dst(ix_ip0_dst),
        .ix_ip_wb_en(ix_ip0_wb_en),
        .ix_ip_op(ix_ip0_op),
        .ix_ip_option(ix_ip0_option),
        .ix_ip_truncate(ix_ip0_truncate),
        .ix_ip_br_type(ix_ip0_br_type),
        .ix_ip_br_neg(ix_ip0_br_neg),
        .ix_ip_br_base(ix_ip0_br_base),
        .ix_ip_br_offset(ix_ip0_br_offset),
        .ix_ip_br_is_call(ix_ip0_br_is_call),
        .ix_ip_br_is_ret(ix_ip0_br_is_ret),
        .ix_ip_operand1(ix_ip0_operand1),
        .ix_ip_operand2(ix_ip0_operand2),
        .ix_ip_bp(ix_ip0_bp),
        .ix_ip_bp_track(ix_ip0_bp_track),
        .ix_ip_bt(ix_ip0_bt),
        .ix_ip_speculate(1'b0),
        .ix_ip_valid(ix_ip0_valid),
        .ix_ip_ready(ix_ip0_ready),
        // Forwarding path back to issue
        .ip_ix_forwarding(ip0_ix_forwarding),
        // To writeback
        .ip_wb_dst(ip0_wb_dst),
        .ip_wb_result(ip0_wb_result),
        .ip_wb_pc(ip0_wb_pc),
        .ip_wb_wb_en(ip0_wb_wb_en),
        .ip_wb_hipri(ip0_wb_hipri),
        .ip_wb_valid(ip0_wb_valid),
        .ip_wb_ready(ip0_wb_ready),
        // To instruction fetch unit
        .ip_if_branch(ip0_if_branch),
        .ip_if_branch_taken(ip0_if_branch_taken),
        .ip_if_branch_pc(ip0_if_branch_pc),
        .ip_if_branch_is_call(ip0_if_branch_is_call),
        .ip_if_branch_is_ret(ip0_if_branch_is_ret),
        .ip_if_branch_track(ip0_if_branch_track),
        .ip_if_pc_override(ip0_if_pc_override),
        .ip_if_new_pc(ip0_if_new_pc),
        // Pipeline flush
        .ip_abort(pipe_flush)
    );

    wire [63:0] ip1_wb_pc;
    wire ip1_wb_ready;
    wire ip1_wb_hipri;
    wire ip1_if_branch;
    wire ip1_if_branch_taken;
    wire [63:0] ip1_if_branch_pc;
    wire ip1_if_branch_is_call;
    wire ip1_if_branch_is_ret;
    wire [1:0] ip1_if_branch_track;
    wire ip1_if_pc_override;
    wire [63:0] ip1_if_new_pc;
    ip #(.IP_HANDLE_BRANCH(1)) ip1(
        .clk(clk),
        .rst(rst),
        // From issue
        .ix_ip_pc(ix_ip1_pc),
        .ix_ip_dst(ix_ip1_dst),
        .ix_ip_wb_en(ix_ip1_wb_en),
        .ix_ip_op(ix_ip1_op),
        .ix_ip_option(ix_ip1_option),
        .ix_ip_truncate(ix_ip1_truncate),
        .ix_ip_br_type(ix_ip1_br_type),
        .ix_ip_br_neg(ix_ip1_br_neg),
        .ix_ip_br_base(ix_ip1_br_base),
        .ix_ip_br_offset(ix_ip1_br_offset),
        .ix_ip_br_is_call(ix_ip1_br_is_call),
        .ix_ip_br_is_ret(ix_ip1_br_is_ret),
        .ix_ip_operand1(ix_ip1_operand1),
        .ix_ip_operand2(ix_ip1_operand2),
        .ix_ip_bp(ix_ip1_bp),
        .ix_ip_bp_track(ix_ip1_bp_track),
        .ix_ip_bt(ix_ip1_bt),
        .ix_ip_speculate(ix_ip1_speculate),
        .ix_ip_valid(ix_ip1_valid),
        .ix_ip_ready(ix_ip1_ready),
        // Forwarding path back to issue
        .ip_ix_forwarding(ip1_ix_forwarding),
        // To writeback
        .ip_wb_dst(ip1_wb_dst),
        .ip_wb_result(ip1_wb_result),
        .ip_wb_pc(ip1_wb_pc),
        .ip_wb_wb_en(ip1_wb_wb_en),
        .ip_wb_hipri(ip1_wb_hipri),
        .ip_wb_valid(ip1_wb_valid),
        .ip_wb_ready(ip1_wb_ready),
        // To instruction fetch unit
        .ip_if_branch(ip1_if_branch),
        .ip_if_branch_taken(ip1_if_branch_taken),
        .ip_if_branch_pc(ip1_if_branch_pc),
        .ip_if_branch_is_call(ip1_if_branch_is_call),
        .ip_if_branch_is_ret(ip1_if_branch_is_ret),
        .ip_if_branch_track(ip1_if_branch_track),
        .ip_if_pc_override(ip1_if_pc_override),
        .ip_if_new_pc(ip1_if_new_pc),
        // Pipeline flush
        .ip_abort(pipe_flush)
    );

    assign ip_if_pc_override = ip0_if_pc_override || ip1_if_pc_override;
    // Currently the pipeline only issue up to 1 branch instruction per cycle
    // A simple mux is good enough.
    assign ip_if_branch = ip0_if_branch || ip1_if_branch;
    assign ip_if_new_pc = ip0_if_branch ? ip0_if_new_pc : ip1_if_new_pc;
    assign ip_if_branch_taken =  ip0_if_branch ? (ip0_if_branch_taken) : (ip1_if_branch_taken);
    assign ip_if_branch_pc = ip0_if_branch ? (ip0_if_branch_pc) : (ip1_if_branch_pc);
    assign ip_if_branch_is_call =  ip0_if_branch ? (ip0_if_branch_is_call) : (ip1_if_branch_is_call);
    assign ip_if_branch_is_ret =  ip0_if_branch ? (ip0_if_branch_is_ret) : (ip1_if_branch_is_ret);
    assign ip_if_branch_track = ip0_if_branch ? (ip0_if_branch_track) : (ip1_if_branch_track);

    lsp lsp(
        .clk(clk),
        .rst(rst),
        // D-mem interface
        .dm_req_addr(dm_req_addr),
        .dm_req_wdata(dm_req_wdata),
        .dm_req_wmask(dm_req_wmask),
        .dm_req_wen(dm_req_wen),
        .dm_req_valid(dm_req_valid),
        .dm_req_ready(dm_req_ready),
        .dm_resp_rdata(dm_resp_rdata),
        .dm_resp_valid(dm_resp_valid),
        // From decoder
        .ix_lsp_pc(ix_lsp_pc),
        .ix_lsp_dst(ix_lsp_dst),
        .ix_lsp_wb_en(ix_lsp_wb_en),
        .ix_lsp_base(ix_lsp_base),
        .ix_lsp_offset(ix_lsp_offset),
        .ix_lsp_source(ix_lsp_source),
        .ix_lsp_mem_sign(ix_lsp_mem_sign),
        .ix_lsp_mem_width(ix_lsp_mem_width),
        .ix_lsp_speculate(ix_lsp_speculate),
        .ix_lsp_valid(ix_lsp_valid),
        .ix_lsp_ready(ix_lsp_ready),
        // To issue for hazard detection
        .lsp_ix_mem_busy(lsp_ix_mem_busy),
        .lsp_ix_mem_wb_en(lsp_ix_mem_wb_en),
        .lsp_ix_mem_dst(lsp_ix_mem_dst),
        .lsp_ix_mem_result(lsp_ix_mem_result),
        .lsp_ix_mem_result_valid(lsp_ix_mem_result_valid),
        // To writeback
        .lsp_wb_dst(lsp_wb_dst),
        .lsp_wb_result(lsp_wb_result),
        .lsp_wb_pc(lsp_wb_pc),
        .lsp_wb_wb_en(lsp_wb_wb_en),
        .lsp_wb_valid(lsp_wb_valid),
        .lsp_wb_ready(lsp_wb_ready),
        // Abort the current AG stage request
        .ag_abort(pipe_flush),
        // Exception
        .lsp_unaligned_load(lsp_unaligned_load),
        .lsp_unaligned_store(lsp_unaligned_store),
        .lsp_unaligned_epc(lsp_unaligned_epc)
    );

    wire [4:0] trap_wb_dst;
    wire [63:0] trap_wb_result;
    wire [63:0] trap_wb_pc;
    wire trap_wb_wb_en;
    wire trap_wb_valid;
    wire trap_wb_ready;
    wire [2:0] wb_trap_instret;
    trap #(.HARTID(HARTID)) trap(
        .clk(clk),
        .rst(rst),
        // External interrupt
        .extint_software(extint_software),
        .extint_timer(extint_timer),
        .extint_external(extint_external),
        // From issue
        .ix_trap_pc(ix_trap_pc),
        .ix_trap_dst(ix_trap_dst),
        .ix_trap_csr_op(ix_trap_csr_op),
        .ix_trap_csr_id(ix_trap_csr_id),
        .ix_trap_csr_opr(ix_trap_csr_opr),
        .ix_trap_mret(ix_trap_mret),
        .ix_trap_int(ix_trap_int),
        .ix_trap_intexc(ix_trap_intexc),
        .ix_trap_cause(ix_trap_cause),
        .ix_trap_valid(ix_trap_valid),
        .ix_trap_ready(ix_trap_ready),
        .trap_ix_ip(trap_ix_ip),
        // To writeback
        .trap_wb_dst(trap_wb_dst),
        .trap_wb_result(trap_wb_result),
        .trap_wb_pc(trap_wb_pc),
        .trap_wb_wb_en(trap_wb_wb_en),
        .trap_wb_valid(trap_wb_valid),
        .trap_wb_ready(trap_wb_ready),
        // From writeback, for counting
        .wb_trap_instret(wb_trap_instret),
        // To instruction fetch unit
        .trap_if_pc_override(trap_if_pc_override),
        .trap_if_new_pc(trap_if_new_pc)
    );

    wire [4:0]  md_wb_dst;
    wire [63:0] md_wb_result;
    wire [63:0] md_wb_pc;
    wire        md_wb_valid;
    wire        md_wb_ready;
    md md(
        .clk(clk),
        .rst(rst),
        // To Issue
        .ix_md_pc(ix_md_pc),
        .ix_md_dst(ix_md_dst),
        .ix_md_operand1(ix_md_operand1),
        .ix_md_operand2(ix_md_operand2),
        .ix_md_md_op(ix_md_md_op),
        .ix_md_muldiv(ix_md_muldiv),
        .ix_md_speculate(ix_md_speculate),
        .ix_md_valid(ix_md_valid),
        .ix_md_ready(ix_md_ready),
        // Hazard detection
        .md_ix_dst(md_ix_dst),
        .md_ix_active(md_ix_active),
        // To writeback
        .md_wb_dst(md_wb_dst),
        .md_wb_result(md_wb_result),
        .md_wb_pc(md_wb_pc),
        .md_wb_valid(md_wb_valid),
        .md_wb_ready(md_wb_ready),
        // This unit doesn't support stall
        .md_abort(pipe_flush)
    );

    wb wb(
        .clk(clk),
        .rst(rst),
        // To register file
        .rf_wen0(rf_wen0),
        .rf_wdst0(rf_wdst0),
        .rf_wdata0(rf_wdata0),
        .rf_wen1(rf_wen1),
        .rf_wdst1(rf_wdst1),
        .rf_wdata1(rf_wdata1),
        // From integer pipe 0
        .ip0_wb_dst(ip0_wb_dst),
        .ip0_wb_result(ip0_wb_result),
        .ip0_wb_pc(ip0_wb_pc),
        .ip0_wb_wb_en(ip0_wb_wb_en),
        .ip0_wb_hipri(ip0_wb_hipri),
        .ip0_wb_valid(ip0_wb_valid),
        .ip0_wb_ready(ip0_wb_ready),
        // From integer pipe 1
        .ip1_wb_dst(ip1_wb_dst),
        .ip1_wb_result(ip1_wb_result),
        .ip1_wb_pc(ip1_wb_pc),
        .ip1_wb_wb_en(ip1_wb_wb_en),
        .ip1_wb_hipri(ip1_wb_hipri),
        .ip1_wb_valid(ip1_wb_valid),
        .ip1_wb_ready(ip1_wb_ready),
        // From load-store pipe
        .lsp_wb_dst(lsp_wb_dst),
        .lsp_wb_result(lsp_wb_result),
        .lsp_wb_pc(lsp_wb_pc),
        .lsp_wb_wb_en(lsp_wb_wb_en),
        .lsp_wb_valid(lsp_wb_valid),
        .lsp_wb_ready(lsp_wb_ready),
        // From muldiv unit
        .md_wb_dst(md_wb_dst),
        .md_wb_result(md_wb_result),
        .md_wb_pc(md_wb_pc),
        .md_wb_valid(md_wb_valid),
        .md_wb_ready(md_wb_ready),
        // From trap unit
        .trap_wb_dst(trap_wb_dst),
        .trap_wb_result(trap_wb_result),
        .trap_wb_pc(trap_wb_pc),
        .trap_wb_wb_en(trap_wb_wb_en),
        .trap_wb_valid(trap_wb_valid),
        .trap_wb_ready(trap_wb_ready),
        // To IX unit
        .wb_ix_buf_value(wb_ix_buf_value),
        .wb_ix_buf_dst(wb_ix_buf_dst),
        .wb_ix_buf_valid(wb_ix_buf_valid),
        // To trap unit
        .wb_trap_instret(wb_trap_instret)
    );

endmodule
