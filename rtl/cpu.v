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

module cpu(
    input  wire         clk,
    input  wire         rst,
    output wire [63:0]  im_req_addr,
    output wire         im_req_valid,
    input  wire         im_req_ready,
    input  wire [63:0]  im_resp_rdata,
    input  wire         im_resp_valid,
    output wire         im_invalidate_req,
    input  wire         im_invalidate_resp,
    output wire [63:0]  dm_req_addr,
    output wire [63:0]  dm_req_wdata,
    output wire [7:0]   dm_req_wmask,
    output wire         dm_req_wen,
    output wire         dm_req_valid,
    input  wire         dm_req_ready,
    input  wire [63:0]  dm_resp_rdata,
    input  wire         dm_resp_valid,
    output wire         dm_flush_req,
    input  wire         dm_flush_resp
);
    // TODO
    wire        lsp_unaligned_load;
    wire        lsp_unaligned_store;

    // Register file
    wire [4:0]  rf_rsrc0;
    wire [63:0] rf_rdata0;
    wire [4:0]  rf_rsrc1;
    wire [63:0] rf_rdata1;
    wire        rf_wen;
    wire [4:0]  rf_wdst;
    wire [63:0] rf_wdata;

    rf rf(
        .clk(clk),
        .rst(rst),
        .rf_rsrc0(rf_rsrc0),
        .rf_rdata0(rf_rdata0),
        .rf_rsrc1(rf_rsrc1),
        .rf_rdata1(rf_rdata1),
        .rf_wen(rf_wen),
        .rf_wdst(rf_wdst),
        .rf_wdata(rf_wdata)
    );

    // IF stage
    wire [63:0] if_dec_pc;
    wire [31:0] if_dec_instr;
    wire        if_dec_bp;
    wire [63:0] if_dec_bt;
    wire        if_dec_valid;
    wire        if_dec_ready;
    wire        ip_if_pc_override;
    wire [63:0] ip_if_new_pc;
    wire        ix_if_pc_override;
    wire [63:0] ix_if_new_pc;
    wire        if_pc_override = ip_if_pc_override || ix_if_pc_override;
    wire [63:0] if_new_pc = ip_if_pc_override ? ip_if_new_pc : ix_if_new_pc;
    wire        pipe_flush = if_pc_override;

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
        .if_dec_pc(if_dec_pc),
        .if_dec_instr(if_dec_instr),
        .if_dec_bp(if_dec_bp),
        .if_dec_bt(if_dec_bt),
        .if_dec_valid(if_dec_valid),
        .if_dec_ready(if_dec_ready),
        // Next PC
        .if_pc_override(if_pc_override),
        .if_new_pc(if_new_pc)
    );

    // Decode stage
    wire [63:0] dec_ix_pc;
    wire        dec_ix_bp;
    wire [63:0] dec_ix_bt;
    wire [3:0]  dec_ix_op;
    wire        dec_ix_option;
    wire        dec_ix_truncate;
    wire [1:0]  dec_ix_br_type;
    wire        dec_ix_br_neg;
    wire        dec_ix_br_base_src;
    wire        dec_ix_br_inj_pc;
    wire        dec_ix_mem_sign;
    wire [1:0]  dec_ix_mem_width;
    wire [1:0]  dec_ix_operand1;
    wire [1:0]  dec_ix_operand2;
    wire [63:0] dec_ix_imm;
    wire [2:0]  dec_ix_op_type;
    wire        dec_ix_legal;
    wire        dec_ix_wb_en;
    wire [4:0]  dec_ix_rs1;
    wire [4:0]  dec_ix_rs2;
    wire [4:0]  dec_ix_rd;
    wire        dec_ix_fencei;
    wire        dec_ix_valid;
    wire        dec_ix_ready;
    dec dec(
        .clk(clk),
        .rst(rst),
        .pipe_flush(pipe_flush),
        // IF interface
        .if_dec_pc(if_dec_pc),
        .if_dec_instr(if_dec_instr),
        .if_dec_bp(if_dec_bp),
        .if_dec_bt(if_dec_bt),
        .if_dec_valid(if_dec_valid),
        .if_dec_ready(if_dec_ready),
        // IX interface
        .dec_ix_pc(dec_ix_pc),
        .dec_ix_bp(dec_ix_bp),
        .dec_ix_bt(dec_ix_bt),
        .dec_ix_op(dec_ix_op),
        .dec_ix_option(dec_ix_option),
        .dec_ix_truncate(dec_ix_truncate),
        .dec_ix_br_type(dec_ix_br_type),
        .dec_ix_br_neg(dec_ix_br_neg),
        .dec_ix_br_base_src(dec_ix_br_base_src),
        .dec_ix_br_inj_pc(dec_ix_br_inj_pc),
        .dec_ix_mem_sign(dec_ix_mem_sign),
        .dec_ix_mem_width(dec_ix_mem_width),
        .dec_ix_operand1(dec_ix_operand1),
        .dec_ix_operand2(dec_ix_operand2),
        .dec_ix_imm(dec_ix_imm),
        .dec_ix_op_type(dec_ix_op_type),
        .dec_ix_legal(dec_ix_legal),
        .dec_ix_wb_en(dec_ix_wb_en),
        .dec_ix_rs1(dec_ix_rs1),
        .dec_ix_rs2(dec_ix_rs2),
        .dec_ix_rd(dec_ix_rd),
        .dec_ix_fencei(dec_ix_fencei),
        .dec_ix_valid(dec_ix_valid),
        .dec_ix_ready(dec_ix_ready)
    );

    // Issue and writeback stage
    wire [63:0] ix_ip_pc;
    wire [4:0]  ix_ip_dst;
    wire        ix_ip_wb_en;
    wire [3:0]  ix_ip_op;
    wire        ix_ip_option;
    wire        ix_ip_truncate;
    wire [1:0]  ix_ip_br_type;
    wire        ix_ip_br_neg;
    wire [63:0] ix_ip_br_base;
    wire [20:0] ix_ip_br_offset;
    wire [63:0] ix_ip_operand1;
    wire [63:0] ix_ip_operand2;
    wire        ix_ip_bp;
    wire [63:0] ix_ip_bt;
    wire        ix_ip_valid;
    wire        ix_ip_ready;
    wire [63:0] ip_ix_forwarding;
    wire [4:0]  ip_wb_dst;
    wire [63:0] ip_wb_result;
    wire [63:0] ip_wb_pc;
    wire        ip_wb_wb_en;
    wire        ip_wb_valid;
    wire        ip_wb_ready;
    wire [63:0] ix_lsp_pc;
    wire [4:0]  ix_lsp_dst;
    wire        ix_lsp_wb_en;
    wire [63:0] ix_lsp_base;
    wire [11:0] ix_lsp_offset;
    wire [63:0] ix_lsp_source;
    wire        ix_lsp_mem_sign;
    wire [1:0]  ix_lsp_mem_width;
    wire        ix_lsp_valid;
    wire        ix_lsp_ready;
    wire        lsp_ix_mem_busy;
    wire        lsp_ix_mem_wb_en;
    wire [4:0]  lsp_ix_mem_dst;
    wire [4:0]  lsp_wb_dst;
    wire [63:0] lsp_wb_result;
    wire [63:0] lsp_wb_pc;
    wire        lsp_wb_wb_en;
    wire        lsp_wb_valid;
    wire        lsp_wb_ready;
    ix ix(
        .clk(clk),
        .rst(rst),
        .pipe_flush(pipe_flush),
        // Register file interface
        .rf_rsrc0(rf_rsrc0),
        .rf_rsrc1(rf_rsrc1),
        .rf_rdata0(rf_rdata0),
        .rf_rdata1(rf_rdata1),
        // IX interface
        .dec_ix_pc(dec_ix_pc),
        .dec_ix_bp(dec_ix_bp),
        .dec_ix_bt(dec_ix_bt),
        .dec_ix_op(dec_ix_op),
        .dec_ix_option(dec_ix_option),
        .dec_ix_truncate(dec_ix_truncate),
        .dec_ix_br_type(dec_ix_br_type),
        .dec_ix_br_neg(dec_ix_br_neg),
        .dec_ix_br_base_src(dec_ix_br_base_src),
        .dec_ix_br_inj_pc(dec_ix_br_inj_pc),
        .dec_ix_mem_sign(dec_ix_mem_sign),
        .dec_ix_mem_width(dec_ix_mem_width),
        .dec_ix_operand1(dec_ix_operand1),
        .dec_ix_operand2(dec_ix_operand2),
        .dec_ix_imm(dec_ix_imm),
        .dec_ix_op_type(dec_ix_op_type),
        .dec_ix_legal(dec_ix_legal),
        .dec_ix_wb_en(dec_ix_wb_en),
        .dec_ix_rs1(dec_ix_rs1),
        .dec_ix_rs2(dec_ix_rs2),
        .dec_ix_rd(dec_ix_rd),
        .dec_ix_fencei(dec_ix_fencei),
        .dec_ix_valid(dec_ix_valid),
        .dec_ix_ready(dec_ix_ready),
        // FU interfaces
        // To integer pipe
        .ix_ip_pc(ix_ip_pc),
        .ix_ip_dst(ix_ip_dst),
        .ix_ip_wb_en(ix_ip_wb_en),
        .ix_ip_op(ix_ip_op),
        .ix_ip_option(ix_ip_option),
        .ix_ip_truncate(ix_ip_truncate),
        .ix_ip_br_type(ix_ip_br_type),
        .ix_ip_br_neg(ix_ip_br_neg),
        .ix_ip_br_base(ix_ip_br_base),
        .ix_ip_br_offset(ix_ip_br_offset),
        .ix_ip_operand1(ix_ip_operand1),
        .ix_ip_operand2(ix_ip_operand2),
        .ix_ip_bp(ix_ip_bp),
        .ix_ip_bt(ix_ip_bt),
        .ix_ip_valid(ix_ip_valid),
        .ix_ip_ready(ix_ip_ready),
        .ip_ix_forwarding(ip_ix_forwarding),
        .ip_wb_dst(ip_wb_dst),
        .ip_wb_result(ip_wb_result),
        .ip_wb_wb_en(ip_wb_wb_en),
        .ip_wb_valid(ip_wb_valid),
        // To load/ store pipe
        .ix_lsp_pc(ix_lsp_pc),
        .ix_lsp_dst(ix_lsp_dst),
        .ix_lsp_wb_en(ix_lsp_wb_en),
        .ix_lsp_base(ix_lsp_base),
        .ix_lsp_offset(ix_lsp_offset),
        .ix_lsp_source(ix_lsp_source),
        .ix_lsp_mem_sign(ix_lsp_mem_sign),
        .ix_lsp_mem_width(ix_lsp_mem_width),
        .ix_lsp_valid(ix_lsp_valid),
        .ix_lsp_ready(ix_lsp_ready),
         // Hazard detection & Bypassing
        .lsp_ix_mem_busy(lsp_ix_mem_busy),
        .lsp_ix_mem_wb_en(lsp_ix_mem_wb_en),
        .lsp_ix_mem_dst(lsp_ix_mem_dst),
        .lsp_wb_dst(lsp_wb_dst),
        .lsp_wb_result(lsp_wb_result),
        .lsp_wb_wb_en(lsp_wb_wb_en),
        .lsp_wb_valid(lsp_wb_valid),
        // Fence I
        .im_invalidate_req(im_invalidate_req),
        .im_invalidate_resp(im_invalidate_resp),
        .dm_flush_req(dm_flush_req),
        .dm_flush_resp(dm_flush_resp),
        .ix_if_pc_override(ix_if_pc_override),
        .ix_if_new_pc(ix_if_new_pc)
    );

    ip ip0(
        .clk(clk),
        .rst(rst),
        // From issue
        .ix_ip_pc(ix_ip_pc),
        .ix_ip_dst(ix_ip_dst),
        .ix_ip_wb_en(ix_ip_wb_en),
        .ix_ip_op(ix_ip_op),
        .ix_ip_option(ix_ip_option),
        .ix_ip_truncate(ix_ip_truncate),
        .ix_ip_br_type(ix_ip_br_type),
        .ix_ip_br_neg(ix_ip_br_neg),
        .ix_ip_br_base(ix_ip_br_base),
        .ix_ip_br_offset(ix_ip_br_offset),
        .ix_ip_operand1(ix_ip_operand1),
        .ix_ip_operand2(ix_ip_operand2),
        .ix_ip_bp(ix_ip_bp),
        .ix_ip_bt(ix_ip_bt),
        .ix_ip_valid(ix_ip_valid),
        .ix_ip_ready(ix_ip_ready),
        // Forwarding path back to issue
        .ip_ix_forwarding(ip_ix_forwarding),
        // To writeback
        .ip_wb_dst(ip_wb_dst),
        .ip_wb_result(ip_wb_result),
        .ip_wb_pc(ip_wb_pc),
        .ip_wb_wb_en(ip_wb_wb_en),
        .ip_wb_valid(ip_wb_valid),
        .ip_wb_ready(ip_wb_ready),
        // To instruction fetch unit
        .ip_if_pc_override(ip_if_pc_override),
        .ip_if_new_pc(ip_if_new_pc)
    );

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
        .ix_lsp_valid(ix_lsp_valid),
        .ix_lsp_ready(ix_lsp_ready),
        // To issue for hazard detection
        .lsp_ix_mem_busy(lsp_ix_mem_busy),
        .lsp_ix_mem_wb_en(lsp_ix_mem_wb_en),
        .lsp_ix_mem_dst(lsp_ix_mem_dst),
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
        .lsp_unaligned_store(lsp_unaligned_store)
    );

    wb wb(
        .clk(clk),
        .rst(rst),
        // To register file
        .rf_wen(rf_wen),
        .rf_wdst(rf_wdst),
        .rf_wdata(rf_wdata),
        // From integer pipe
        .ip_wb_dst(ip_wb_dst),
        .ip_wb_result(ip_wb_result),
        .ip_wb_pc(ip_wb_pc),
        .ip_wb_wb_en(ip_wb_wb_en),
        .ip_wb_valid(ip_wb_valid),
        .ip_wb_ready(ip_wb_ready),
        // From load-store pipe
        .lsp_wb_dst(lsp_wb_dst),
        .lsp_wb_result(lsp_wb_result),
        .lsp_wb_pc(lsp_wb_pc),
        .lsp_wb_wb_en(lsp_wb_wb_en),
        .lsp_wb_valid(lsp_wb_valid),
        .lsp_wb_ready(lsp_wb_ready)
    );

endmodule
