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

module ix(
    input  wire         clk,
    input  wire         rst,
    input  wire         pipe_flush,
    // IX interface
    input  wire [63:0]  dec_ix_pc,
    input  wire         dec_ix_bp,
    input  wire [63:0]  dec_ix_bt,
    input  wire [2:0]   dec_ix_op,
    input  wire         dec_ix_option,
    input  wire         dec_ix_truncate,
    input  wire [1:0]   dec_ix_br_type,
    input  wire         dec_ix_mem_sign,
    input  wire [1:0]   dec_ix_mem_width,
    input  wire [1:0]   dec_ix_operand1,
    input  wire [1:0]   dec_ix_operand2,
    input  wire [63:0]  dec_ix_imm,
    input  wire [2:0]   dec_ix_op_type,
    input  wire         dec_ix_legal,
    input  wire         dec_ix_wb_en,
    input  wire [4:0]   dec_ix_rs1,
    input  wire [4:0]   dec_ix_rs2,
    input  wire [4:0]   dec_ix_rd,
    input  wire         dec_ix_valid,
    output wire         dec_ix_ready,
    // FU interfaces
    // To integer pipe
    output reg  [63:0]  ix_ip_pc,
    output reg  [4:0]   ix_ip_dst,
    output reg          ix_ip_wb_en,
    output reg  [2:0]   ix_ip_op,
    output reg          ix_ip_option,
    output reg          ix_ip_truncate,
    output reg  [1:0]   ix_ip_br_type,
    output reg  [20:0]  ix_ip_boffset,
    output reg  [63:0]  ix_ip_operand1,
    output reg  [63:0]  ix_ip_operand2,
    output reg          ix_ip_bp,
    output reg  [63:0]  ix_ip_bt,
    output reg          ix_ip_valid,
    input  wire         ix_ip_ready,
    input  wire [63:0]  ip_ix_forwarding,
    input  wire [4:0]   ip_ix_dst,
    input  wire [63:0]  ip_ix_result,
    input  wire [63:0]  ip_ix_pc,
    input  wire         ip_ix_wb_en,
    input  wire         ip_ix_valid,
    output wire         ip_ix_ready,
    // To load/ store pipe
    output reg  [63:0]  ix_lsp_pc,
    output reg  [4:0]   ix_lsp_dst,
    output reg          ix_lsp_wb_en,
    output reg  [63:0]  ix_lsp_base,
    output reg  [11:0]  ix_lsp_offset,
    output reg  [63:0]  ix_lsp_source,
    output reg          ix_lsp_mem_sign,
    output reg  [1:0]   ix_lsp_mem_width,
    output reg          ix_lsp_valid,
    input  wire         ix_lsp_ready,
    input  wire         lsp_ix_mem_wb_en,
    input  wire [4:0]   lsp_ix_mem_dst,
    input  wire [4:0]   lsp_ix_dst,
    input  wire [63:0]  lsp_ix_result,
    input  wire [63:0]  lsp_ix_pc,
    input  wire         lsp_ix_wb_en,
    input  wire         lsp_ix_valid,
    output wire         lsp_ix_ready
);

    // Regfile
    reg [63:0] rf [31:1];

    // Hazard detection
    wire [4:0] ix_rs [0:1];
    assign ix_rs[0] = dec_ix_rs1;
    assign ix_rs[1] = dec_ix_rs2;
    reg [0:0] rs_ready [0:1];
    reg [63:0] rs_val [0:63];
    genvar i;
    generate
        for (i = 0; i < 2; i = i + 1) begin
            always @(*) begin
                rs_ready[i] = 1'b1;
                // Register read
                rs_val[i] = (ix_rs[i] == 5'd0) ? (64'd0) : rf[ix_rs[i]];
                // Forwarding point: IP execution
                if (ix_ip_valid && ix_ip_ready && ix_ip_wb_en &&
                        (ix_ip_dst == ix_rs[i])) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = ip_ix_forwarding;
                end
                // Forwarding point: IP writeback
                if (ip_ix_valid && ip_ix_wb_en && (ip_ix_dst == ix_rs[i])) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = ip_ix_result;
                end
                // Stall point: LSP address generation
                if (ix_lsp_valid && ix_lsp_ready && ix_lsp_wb_en &&
                        (ix_lsp_dst == ix_rs[i])) begin
                    rs_ready[i] = 1'b0;
                end
                // Stall point: LSP memory access active
                if (lsp_ix_mem_wb_en && (lsp_ix_mem_dst == ix_rs[i])) begin
                    rs_ready[i] = 1'b0;
                end
                // Forwarding point: LSP writeback
                if (lsp_ix_valid && lsp_ix_wb_en &&
                        (lsp_ix_dst == ix_rs[i])) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = lsp_ix_result;
                end
            end
        end
    endgenerate

    wire operand1_ready = (dec_ix_operand1 == `D_OPR1_RS1) ? rs_ready[0] : 1'b1;
    wire operand2_ready = (dec_ix_operand2 == `D_OPR2_RS2) ? rs_ready[1] : 1'b1;

    wire [63:0] operand1_value =
            (dec_ix_operand1 == `D_OPR1_RS1) ? (rs_val[0]) :
            (dec_ix_operand1 == `D_OPR1_PC) ? (dec_ix_pc) :
            (dec_ix_operand1 == `D_OPR1_ZERO) ? (64'd0) : (64'bx);
    wire [63:0] operand2_value =
            (dec_ix_operand2 == `D_OPR2_RS2) ? (rs_val[1]) :
            (dec_ix_operand2 == `D_OPR2_IMM) ? (dec_ix_imm) : (64'bx);

    wire ix_opr_ready = operand1_ready && operand2_ready;
    wire ix_issue_ip0 = (dec_ix_valid) && (dec_ix_legal) && (ix_opr_ready) &&
            ((dec_ix_op_type == `OT_INT) || (dec_ix_op_type == `OT_BRANCH)) &&
            (ix_ip_ready) && !pipe_flush;
    wire ix_issue_lsp = (dec_ix_valid) && (dec_ix_legal) && (ix_opr_ready) &&
            ((dec_ix_op_type == `OT_LOAD) || (dec_ix_op_type == `OT_STORE)) &&
            (ix_lsp_ready) && !pipe_flush;
    wire ix_issue = ix_issue_ip0 || ix_issue_lsp;

    wire ix_stall = dec_ix_valid && !ix_issue && !pipe_flush;
    assign dec_ix_ready = !rst && !ix_stall;

    always @(posedge clk) begin
        if (rst) begin
            ix_ip_valid <= 1'b0;
            ix_lsp_valid <= 1'b0;
        end
        else begin
            if (ix_issue_ip0) begin
                ix_ip_op <= dec_ix_op;
                ix_ip_option <= dec_ix_option;
                ix_ip_truncate <= dec_ix_truncate;
                ix_ip_br_type <= dec_ix_br_type;
                ix_ip_boffset <= dec_ix_imm[20:0];
                ix_ip_operand1 <= operand1_value;
                ix_ip_operand2 <= operand2_value;
                ix_ip_bp <= dec_ix_bp;
                ix_ip_bt <= dec_ix_bt;
                ix_ip_wb_en <= dec_ix_wb_en;
                ix_ip_dst <= dec_ix_rd;
                ix_ip_pc <= dec_ix_pc;
                ix_ip_valid <= 1'b1;
            end
            else if (ix_ip_ready) begin
                ix_ip_valid <= 1'b0;
            end
            if (ix_issue_lsp) begin
                ix_lsp_base <= operand1_value;
                ix_lsp_offset <= dec_ix_imm[11:0];
                ix_lsp_source <= operand2_value;
                ix_lsp_mem_sign <= dec_ix_mem_sign;
                ix_lsp_mem_width <= dec_ix_mem_width;
                ix_lsp_wb_en <= dec_ix_wb_en;
                ix_lsp_dst <= dec_ix_rd;
                ix_lsp_pc <= dec_ix_pc;
                ix_lsp_valid <= 1'b1;
            end
            else if (ix_lsp_ready) begin
                ix_lsp_valid <= 1'b0;
            end
        end
    end

    // Writeback
    wire ip_wb_req = ip_ix_valid && ip_ix_wb_en;
    wire lsp_wb_req = lsp_ix_valid && lsp_ix_wb_en;
    // Retire without writeback
    wire ip_rwowb_req = ip_ix_valid && !ip_ix_wb_en;
    wire lsp_rwowb_req = lsp_ix_valid && !lsp_ix_wb_en;
    // Always prefer accepting memory request for now
    wire ip_wb_ac = !lsp_wb_ac && ip_wb_req;
    wire lsp_wb_ac = lsp_wb_req;

    wire wb_active = ip_wb_ac || lsp_wb_ac;
    wire [4:0] wb_dst =
            (ip_wb_ac) ? ip_ix_dst :
            (lsp_wb_ac) ? lsp_ix_dst : 5'bx;
    wire [63:0] wb_value =
            (ip_wb_ac) ? ip_ix_result :
            (lsp_wb_ac) ? lsp_ix_result : 64'bx;
    wire [63:0] wb_pc =
            (ip_wb_ac) ? ip_ix_pc :
            (lsp_wb_ac) ? lsp_ix_pc : 64'bx;
    always @(posedge clk) begin
        begin
            if (wb_active) begin
                rf[wb_dst] <= wb_value;
                $display("PC %016x WB [%d] <- %016x", wb_pc, wb_dst, wb_value);
            end
            if (ip_rwowb_req) begin
                $display("PC %016x RETIRE FROM IP", ip_ix_pc);
            end
            if (lsp_rwowb_req) begin
                $display("PC %016x RETIRE FROM LSP", lsp_ix_pc);
            end
        end
    end

    // Acknowledge accepted wb, always acknowledge retire without writeback
    assign ip_ix_ready = !(ip_ix_valid && (!ip_wb_ac || ip_rwowb_req));
    assign lsp_ix_ready = !(lsp_ix_valid && (!lsp_wb_ac && !lsp_rwowb_req));

endmodule
