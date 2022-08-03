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
    /* verilator lint_off UNUSED */
    input  wire         clk,
    input  wire         rst,
    /* verilator lint_on UNUSED */
    // To register file
    output wire         rf_wen,
    output wire [4:0]   rf_wdst,
    output wire [63:0]  rf_wdata,
    // From integer pipe
    input  wire [4:0]   ip_wb_dst,
    input  wire [63:0]  ip_wb_result,
    /* verilator lint_off UNUSED */
    input  wire [63:0]  ip_wb_pc,
    /* verilator lint_on UNUSED */
    input  wire         ip_wb_wb_en,
    input  wire         ip_wb_hipri,
    input  wire         ip_wb_valid,
    output wire         ip_wb_ready,
    // From load-store pipe
    input  wire [4:0]   lsp_wb_dst,
    input  wire [63:0]  lsp_wb_result,
    /* verilator lint_off UNUSED */
    input  wire [63:0]  lsp_wb_pc,
    /* verilator lint_on UNUSED */
    input  wire         lsp_wb_wb_en,
    input  wire         lsp_wb_valid,
    output wire         lsp_wb_ready,
    // From muldiv unit
    input  wire [4:0]   md_wb_dst,
    input  wire [63:0]  md_wb_result,
    /* verilator lint_off UNUSED */
    input  wire [63:0]  md_wb_pc,
    /* verilator lint_on UNUSED */
    input  wire         md_wb_valid,
    output wire         md_wb_ready,
    // From trap unit
    input  wire [4:0]   trap_wb_dst,
    input  wire [63:0]  trap_wb_result,
    /* verilator lint_off UNUSED */
    input  wire [63:0]  trap_wb_pc,
    /* verilator lint_on UNUSED */
    input  wire         trap_wb_wb_en,
    input  wire         trap_wb_valid,
    output wire         trap_wb_ready,
    // To trap unit
    output wire [1:0]   wb_trap_instret
);

    // Writeback
    wire ip_wb_req = ip_wb_valid && ip_wb_wb_en;
    wire lsp_wb_req = lsp_wb_valid && lsp_wb_wb_en;
    wire md_wb_req = md_wb_valid;
    wire trap_wb_req = trap_wb_valid && trap_wb_wb_en;
    // Retire without writeback
    wire ip_rwowb_req = ip_wb_valid && !ip_wb_wb_en;
    wire lsp_rwowb_req = lsp_wb_valid && !lsp_wb_wb_en;
    wire trap_rwowb_req = trap_wb_valid && !trap_wb_wb_en;
    // Always prefer accepting memory request for now
    // Current priority: md > lsp > ip > trap. Though trap shouldn't have
    // collision with other types
    wire md_wb_ac = md_wb_req && !ip_wb_hipri;
    wire lsp_wb_ac = (!md_wb_ac && !ip_wb_hipri) && lsp_wb_req;
    wire ip_wb_ac = (!md_wb_ac && !lsp_wb_ac) && ip_wb_req;
    wire trap_wb_ac = (!md_wb_ac && !lsp_wb_ac && !ip_wb_ac) && trap_wb_req;

    wire wb_active = ip_wb_ac || lsp_wb_ac || md_wb_ac || trap_wb_ac;
    wire [4:0] wb_dst =
            (ip_wb_ac) ? ip_wb_dst :
            (lsp_wb_ac) ? lsp_wb_dst :
            (md_wb_ac) ? md_wb_dst :
            (trap_wb_ac) ? trap_wb_dst: 5'bx;
    wire [63:0] wb_value =
            (ip_wb_ac) ? ip_wb_result :
            (lsp_wb_ac) ? lsp_wb_result :
            (md_wb_ac) ? md_wb_result :
            (trap_wb_ac) ? trap_wb_result : 64'bx;

    `ifdef VERBOSE
    wire [63:0] wb_pc =
            (ip_wb_ac) ? ip_wb_pc :
            (lsp_wb_ac) ? lsp_wb_pc :
            (md_wb_ac) ? md_wb_pc :
            (trap_wb_ac) ? trap_wb_pc : 64'bx;
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
            if (trap_rwowb_req) begin
                $display("PC %016x RETIRE FROM TRAP", trap_wb_pc);
            end
        end
    end
    `endif

    assign rf_wen = wb_active;
    assign rf_wdst = wb_dst;
    assign rf_wdata = wb_value;

    // Acknowledge accepted wb, always acknowledge retire without writeback
    assign ip_wb_ready = !(ip_wb_valid && (!ip_wb_ac && !ip_rwowb_req));
    assign lsp_wb_ready = !(lsp_wb_valid && (!lsp_wb_ac && !lsp_rwowb_req));
    assign md_wb_ready = !(md_wb_valid && !md_wb_ac);
    assign trap_wb_ready = !(trap_wb_valid && (!trap_wb_ac && !trap_rwowb_req));

    // Instruction retire count
    reg ip_retire;
    reg lsp_retire;
    reg md_retire;
    reg trap_retire;
    always @(posedge clk) begin
        ip_retire <= (ip_wb_valid && ip_wb_ready);
        lsp_retire <= (lsp_wb_valid && lsp_wb_ready);
        md_retire <= md_wb_ac;
        trap_retire <= (trap_wb_valid && trap_wb_ready);
        if (rst) begin
            ip_retire <= 1'b0;
            lsp_retire <= 1'b0;
            md_retire <= 1'b0;
            trap_retire <= 1'b0;
        end
    end
    assign wb_trap_instret = ip_retire + lsp_retire + md_retire + trap_retire;

endmodule
