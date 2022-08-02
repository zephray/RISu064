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
    output reg  [7:0]   dm_req_wmask,
    output reg          dm_req_wen,
    output wire         dm_req_valid,
    input  wire         dm_req_ready,
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
    output wire         lsp_ix_mem_busy,
    // To writeback
    output wire [4:0]   lsp_wb_dst,
    output wire [63:0]  lsp_wb_result,
    output wire [63:0]  lsp_wb_pc,
    output wire         lsp_wb_wb_en,
    output wire         lsp_wb_valid,
    input  wire         lsp_wb_ready,
    // Abort the current AG stage request
    input  wire         ag_abort,
    // Exception
    output reg          lsp_unaligned_load,
    output reg          lsp_unaligned_store,
    output wire [63:0]  lsp_unaligned_epc
);

    // AGU
    wire [63:0] agu_addr;
    assign agu_addr = ix_lsp_base + {{52{ix_lsp_offset[11]}}, ix_lsp_offset};
    
    wire lsp_stalled_memory_resp = (m_wb_req_valid && !dm_resp_valid) && !rst;
    wire lsp_stalled_back_pressure = (!lsp_wb_ready) && !rst;
    wire lsp_stalled = lsp_stalled_memory_resp || lsp_stalled_back_pressure;
    reg lsp_stalled_last;
    assign ix_lsp_ready = (!lsp_stalled && !lsp_stalled_last &&
            !(lsp_memreq_last && !dm_req_ready));
    reg lsp_memreq_last;

    reg ag_m_valid;
    reg [63:0] ag_m_pc;
    reg [4:0] ag_m_dst;
    reg ag_m_wb_en;
    reg [2:0] ag_m_byte_offset;
    reg ag_m_mem_sign;
    reg [1:0] ag_m_mem_width;

    // Mask and data generation
    wire handshaking = ix_lsp_valid && ix_lsp_ready;
    wire ualign_h = (ix_lsp_mem_width == `MW_HALF) && (agu_addr[0] != 1'b0);
    wire ualign_w = (ix_lsp_mem_width == `MW_WORD) && (agu_addr[1:0] != 2'b0);
    wire ualign_d = (ix_lsp_mem_width == `MW_DOUBLE) && (agu_addr[2:0] != 3'b0);
    wire ualign = ualign_h || ualign_w || ualign_d;

    wire [63:0] mem_wdata =
            (ix_lsp_mem_width == `MW_BYTE) ? {8{ix_lsp_source[7:0]}} :
            (ix_lsp_mem_width == `MW_HALF) ? {4{ix_lsp_source[15:0]}} :
            (ix_lsp_mem_width == `MW_WORD) ? {2{ix_lsp_source[31:0]}} :
            ix_lsp_source;
    wire [7:0] mem_wmask_byte;
    wire [7:0] mem_wmask_half;
    wire [7:0] mem_wmask_word;
    genvar i;
    generate
    for (i = 0; i < 8; i = i + 1) begin
        assign mem_wmask_byte[i] = (agu_addr[2:0] == i);
    end
    for (i = 0; i < 4; i = i + 1) begin
        assign mem_wmask_half[i*2+1:i*2] = {2{mem_wmask_byte[i*2]}};
    end
    for (i = 0; i < 2; i = i + 1) begin
        assign mem_wmask_word[i*4+3:i*4] = {4{mem_wmask_byte[i*4]}};
    end
    endgenerate
    wire [7:0] mem_wmask =
            (ix_lsp_mem_width == `MW_BYTE) ? mem_wmask_byte :
            (ix_lsp_mem_width == `MW_HALF) ? mem_wmask_half :
            (ix_lsp_mem_width == `MW_WORD) ? mem_wmask_word :
            8'hff;

    // AG stage
    always @(posedge clk) begin
        if (handshaking) begin
            dm_req_addr <= agu_addr;
            dm_req_wdata <= mem_wdata;
            dm_req_wmask <= mem_wmask;
            dm_req_wen <= !ix_lsp_wb_en;
            ag_m_valid <= !ag_abort && !ualign; // Cancel unaligned access
            ag_m_pc <= ix_lsp_pc;
            ag_m_dst <= ix_lsp_dst;
            ag_m_wb_en <= ix_lsp_wb_en;
            ag_m_byte_offset <= agu_addr[2:0];
            ag_m_mem_sign <= ix_lsp_mem_sign;
            ag_m_mem_width <= ix_lsp_mem_width;
            lsp_unaligned_load <= !ag_abort && ualign && !ix_lsp_wb_en;
            lsp_unaligned_store <= !ag_abort && ualign && ix_lsp_wb_en;
        end
        else begin
            if (!lsp_stalled) begin
                ag_m_valid <= 1'b0;
            end
            lsp_unaligned_load <= 1'b0;
            lsp_unaligned_store <= 1'b0;
        end
        lsp_stalled_last <= lsp_stalled;
        lsp_memreq_last <= dm_req_valid;

        if (rst) begin
            lsp_stalled_last <= 1'b0;
            ag_m_valid <= 1'b0;
            lsp_unaligned_load <= 1'b0;
            lsp_unaligned_store <= 1'b0;
        end
    end

    assign lsp_unaligned_epc = ag_m_pc;

    // For hazard detection
    assign lsp_ix_mem_busy = dm_req_valid || lsp_stalled;

    // Memory stage
    reg m_wb_req_valid;
    reg [63:0] m_wb_pc;
    reg [4:0] m_wb_dst;
    reg m_wb_wb_en;
    reg [2:0] m_wb_byte_offset;
    reg m_wb_mem_sign;
    reg [1:0] m_wb_mem_width;
    always @(posedge clk) begin
        if (!lsp_stalled_memory_resp) begin
            m_wb_req_valid <= dm_req_valid && dm_req_ready;
        end
        if (!lsp_stalled) begin
            m_wb_pc <= ag_m_pc;
            m_wb_dst <= ag_m_dst;
            m_wb_wb_en <= ag_m_wb_en;
            m_wb_byte_offset <= ag_m_byte_offset;
            m_wb_mem_sign <= ag_m_mem_sign;
            m_wb_mem_width <= ag_m_mem_width;
        end
    end

    assign dm_req_valid = ag_m_valid && !lsp_stalled;

    wire [63:0] mem_rd = dm_resp_rdata;

    wire [1:0] m_wb_half_offset = m_wb_byte_offset[2:1];
    wire m_wb_word_offset = m_wb_byte_offset[2];

    wire [7:0] mem_rd_bl [0:7];
    wire [15:0] mem_rd_hl [0:3];
    wire [31:0] mem_rd_wl [0:1];
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
    wire [15:0] mem_rd_h = mem_rd_hl[m_wb_half_offset];
    wire [31:0] mem_rd_w = mem_rd_wl[m_wb_word_offset];

    wire [63:0] mem_rd_bu = {56'b0, mem_rd_b};
    wire [63:0] mem_rd_bs = {{56{mem_rd_b[7]}}, mem_rd_b};
    wire [63:0] mem_rd_hu = {48'b0, mem_rd_h};
    wire [63:0] mem_rd_hs = {{48{mem_rd_h[15]}}, mem_rd_h};
    wire [63:0] mem_rd_wu = {32'b0, mem_rd_w};
    wire [63:0] mem_rd_ws = {{32{mem_rd_w[31]}}, mem_rd_w};

    wire [63:0] m_wb_result = 
        (m_wb_mem_width == `MW_BYTE) ? (m_wb_mem_sign ? mem_rd_bu : mem_rd_bs) :
        (m_wb_mem_width == `MW_HALF) ? (m_wb_mem_sign ? mem_rd_hu : mem_rd_hs) :
        (m_wb_mem_width == `MW_WORD) ? (m_wb_mem_sign ? mem_rd_wu : mem_rd_ws) :
        (mem_rd);
    
    fifo_2d_fwft #(.WIDTH(134)) lsp_fifo (
        .clk(clk),
        .rst(rst),
        .a_data({m_wb_result, m_wb_pc, m_wb_dst, m_wb_wb_en}),
        .a_valid(dm_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .b_data({lsp_wb_result, lsp_wb_pc, lsp_wb_dst, lsp_wb_wb_en}),
        .b_valid(lsp_wb_valid),
        .b_ready(lsp_wb_ready)
    );

endmodule
