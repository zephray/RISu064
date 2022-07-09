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

// Load store pipeline
// Pipeline latency = 2+ cycle
module lsp(
    input  wire         clk,
    input  wire         rst,
    // D-mem interface
    output reg  [63:0]  dm_req_addr,
    output reg  [63:0]  dm_req_wdata,
    output reg          dm_req_wen,
    output reg          dm_req_valid,
    input  wire [63:0]  dm_resp_rdata,
    input  wire         dm_resp_valid,
    // From issue
    input  wire [63:0]  ix_lsp_pc,
    input  wire [4:0]   ix_lsp_dst,
    input  wire         ix_lsp_wb_en,
    input  wire [63:0]  ix_lsp_base,
    input  wire [11:0]  ix_lsp_offset,
    input  wire [63:0]  ix_lsp_source,
    input  wire         ix_lsp_mem_sign,
    input  wire [1:0]   ix_lsp_mem_width,
    input  wire         ix_lsp_valid,
    output wire         ix_lsp_ready,
    // To issue for hazard detection
    output wire         lsp_ix_mem_wb_en,
    output wire [4:0]   lsp_ix_mem_dst,
    // To writeback
    output reg  [4:0]   lsp_ix_dst,
    output wire [63:0]  lsp_ix_result,
    output reg  [63:0]  lsp_ix_pc,
    output reg          lsp_ix_wb_en,
    output wire         lsp_ix_valid,
    input  wire         lsp_ix_ready
);

    // AGU
    wire [63:0] agu_addr;
    assign agu_addr = ix_lsp_base + {{52{ix_lsp_offset[11]}}, ix_lsp_offset};
    
    wire lsp_stalled = dm_req_valid && !dm_resp_valid;
    assign ix_lsp_ready = !lsp_stalled;

    reg [63:0] ag_m_pc;
    reg [4:0] ag_m_dst;
    reg ag_m_wb_en;
    reg [2:0] ag_m_byte_offset;
    reg ag_m_mem_sign;
    reg [1:0] ag_m_mem_width;

    // AG stage
    always @(posedge clk) begin
        if (ix_lsp_valid) begin
            dm_req_addr <= agu_addr;
            dm_req_wdata <= ix_lsp_source;
            dm_req_wen <= !ix_lsp_wb_en;
            dm_req_valid <= 1'b1;
            ag_m_pc <= ix_lsp_pc;
            ag_m_dst <= ix_lsp_dst;
            ag_m_wb_en <= ix_lsp_wb_en;
            ag_m_byte_offset <= agu_addr[2:0];
            ag_m_mem_sign <= ix_lsp_mem_sign;
            ag_m_mem_width <= ix_lsp_mem_width;
        end
        else begin
            dm_req_valid <= 1'b0;
        end
    end

    // For hazard detection
    assign lsp_ix_mem_wb_en = ag_m_wb_en && dm_req_valid;
    assign lsp_ix_mem_dst = ag_m_dst;

    // Memory stage
    reg [2:0] m_wb_byte_offset;
    reg m_wb_mem_sign;
    reg [1:0] m_wb_mem_width;
    always @(posedge clk) begin
        lsp_ix_pc <= ag_m_pc;
        lsp_ix_dst <= ag_m_dst;
        lsp_ix_wb_en <= ag_m_wb_en;
        m_wb_byte_offset <= ag_m_byte_offset;
        m_wb_mem_sign <= ag_m_mem_sign;
        m_wb_mem_width <= ag_m_mem_width;
    end

    wire [63:0] mem_rd;
    // 1-deep FWFT FIFO
    fifo_1d_fwft #(.WIDTH(64)) lsp_fifo(
        .clk(clk),
        .rst(rst),
        .a_data(dm_resp_rdata),
        .a_valid(dm_resp_valid && lsp_ix_wb_en),
        .a_ready(),
        .b_data(mem_rd),
        .b_valid(lsp_ix_valid),
        .b_ready(lsp_ix_ready)
    );

    wire [1:0] m_wb_half_offset = m_wb_byte_offset[2:1];
    wire m_wb_word_offset = m_wb_byte_offset[2];

    wire [7:0] mem_rd_bl [0:7];
    wire [15:0] mem_rd_hl [0:3];
    wire [31:0] mem_rd_wl [0:1];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin
            assign mem_rd_bl[i] = mem_rd[i*8+7:i*8];
        end
        for (i = 0; i < 4; i = i + 1) begin
            assign mem_rd_hl[i] = mem_rd[i*16+15:i*16];
        end
        for (i = 0; i < 2; i = i + 1) begin
            assign mem_rd_wl[i] = mem_rd[i*32+31:i*32];
        end
    endgenerate


    wire [7:0] mem_rd_b = mem_rd_bl[m_wb_byte_offset];
    wire [31:0] mem_rd_w = mem_rd_wl[m_wb_word_offset];
    wire [15:0] mem_rd_h = mem_rd_hl[m_wb_half_offset];

    wire [63:0] mem_rd_bu = {56'b0, mem_rd_b};
    wire [63:0] mem_rd_bs = {{56{mem_rd_b[7]}}, mem_rd_b};
    wire [63:0] mem_rd_hu = {48'b0, mem_rd_h};
    wire [63:0] mem_rd_hs = {{48{mem_rd_h[15]}}, mem_rd_h};
    wire [63:0] mem_rd_wu = {32'b0, mem_rd_w};
    wire [63:0] mem_rd_ws = {{32{mem_rd_w[31]}}, mem_rd_w};

    assign lsp_ix_result = 
        (m_wb_mem_width == `MW_BYTE) ? (m_wb_mem_sign ? mem_rd_bu : mem_rd_bs) :
        (m_wb_mem_width == `MW_HALF) ? (m_wb_mem_sign ? mem_rd_hu : mem_rd_hs) :
        (m_wb_mem_width == `MW_WORD) ? (m_wb_mem_sign ? mem_rd_wu : mem_rd_ws) :
        (mem_rd);

endmodule
