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

module wb(
    input  wire         clk,
    input  wire         rst,
    // To register file
    output wire         rf_wen [0:0],
    output wire [4:0]   rf_wdst [0:0],
    output wire [63:0]  rf_wdata [0:0],
    // From integer pipe
    input  wire [4:0]   ip_wb_dst,
    input  wire [63:0]  ip_wb_result,
    input  wire [63:0]  ip_wb_pc,
    input  wire         ip_wb_wb_en,
    input  wire         ip_wb_valid,
    output wire         ip_wb_ready,
    // From load-store pipe
    input  wire [4:0]   lsp_wb_dst,
    input  wire [63:0]  lsp_wb_result,
    input  wire [63:0]  lsp_wb_pc,
    input  wire         lsp_wb_wb_en,
    input  wire         lsp_wb_valid,
    output wire         lsp_wb_ready
);

    // Writeback
    wire ip_wb_req = ip_wb_valid && ip_wb_wb_en;
    wire lsp_wb_req = lsp_wb_valid && lsp_wb_wb_en;
    // Retire without writeback
    wire ip_rwowb_req = ip_wb_valid && !ip_wb_wb_en;
    wire lsp_rwowb_req = lsp_wb_valid && !lsp_wb_wb_en;
    // Always prefer accepting memory request for now
    wire ip_wb_ac = !lsp_wb_ac && ip_wb_req;
    wire lsp_wb_ac = lsp_wb_req;

    wire wb_active = ip_wb_ac || lsp_wb_ac;
    wire [4:0] wb_dst =
            (ip_wb_ac) ? ip_wb_dst :
            (lsp_wb_ac) ? lsp_wb_dst : 5'bx;
    wire [63:0] wb_value =
            (ip_wb_ac) ? ip_wb_result :
            (lsp_wb_ac) ? lsp_wb_result : 64'bx;
    wire [63:0] wb_pc =
            (ip_wb_ac) ? ip_wb_pc :
            (lsp_wb_ac) ? lsp_wb_pc : 64'bx;
    always @(posedge clk) begin
        begin
            if (wb_active) begin
                $display("PC %016x WB [%d] <- %016x", wb_pc, wb_dst, wb_value);
            end
            if (ip_rwowb_req) begin
                $display("PC %016x RETIRE FROM IP", ip_wb_pc);
            end
            if (lsp_rwowb_req) begin
                $display("PC %016x RETIRE FROM LSP", lsp_wb_pc);
            end
        end
    end

    assign rf_wen[0] = wb_active;
    assign rf_wdst[0] = wb_dst;
    assign rf_wdata[0] = wb_value;

    // Acknowledge accepted wb, always acknowledge retire without writeback
    assign ip_wb_ready = !(ip_wb_valid && (!ip_wb_ac && !ip_rwowb_req));
    assign lsp_wb_ready = !(lsp_wb_valid && (!lsp_wb_ac && !lsp_rwowb_req));


endmodule
