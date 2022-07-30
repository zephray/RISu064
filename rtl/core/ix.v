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
    // Register file interface
    output wire [4:0]   rf_rsrc0,
    input  wire [63:0]  rf_rdata0,
    output wire [4:0]   rf_rsrc1,
    input  wire [63:0]  rf_rdata1,
    // IX interface
    input  wire [63:0]  dec_ix_pc,
    input  wire         dec_ix_bp,
    input  wire [63:0]  dec_ix_bt,
    input  wire [3:0]   dec_ix_op,
    input  wire         dec_ix_option,
    input  wire         dec_ix_truncate,
    input  wire [1:0]   dec_ix_br_type,
    input  wire         dec_ix_br_neg,
    input  wire         dec_ix_br_base_src,
    input  wire         dec_ix_br_inj_pc,
    input  wire         dec_ix_mem_sign,
    input  wire [1:0]   dec_ix_mem_width,
    input  wire [1:0]   dec_ix_csr_op,
    input  wire         dec_ix_mret,
    input  wire         dec_ix_intr,
    input  wire [3:0]   dec_ix_cause,
    input  wire [2:0]   dec_ix_md_op,
    input  wire         dec_ix_muldiv,
    input  wire [2:0]   dec_ix_op_type,
    input  wire [1:0]   dec_ix_operand1,
    input  wire [1:0]   dec_ix_operand2,
    input  wire [63:0]  dec_ix_imm,
    input  wire         dec_ix_legal,
    input  wire         dec_ix_wb_en,
    input  wire [4:0]   dec_ix_rs1,
    input  wire [4:0]   dec_ix_rs2,
    input  wire [4:0]   dec_ix_rd,
    input  wire         dec_ix_fencei,
    input  wire         dec_ix_valid,
    output wire         dec_ix_ready,
    // FU interfaces
    // To integer pipe
    output reg  [63:0]  ix_ip_pc,
    output reg  [4:0]   ix_ip_dst,
    output reg          ix_ip_wb_en,
    output reg  [3:0]   ix_ip_op,
    output reg          ix_ip_option,
    output reg          ix_ip_truncate,
    output reg  [1:0]   ix_ip_br_type,
    output reg          ix_ip_br_neg,
    output reg  [63:0]  ix_ip_br_base,
    output reg  [20:0]  ix_ip_br_offset,
    output reg  [63:0]  ix_ip_operand1,
    output reg  [63:0]  ix_ip_operand2,
    output reg          ix_ip_bp,
    output reg  [63:0]  ix_ip_bt,
    output reg          ix_ip_valid,
    input  wire         ix_ip_ready,
    // Hazard detection & Bypassing
    input  wire [63:0]  ip_ix_forwarding,
    input  wire [4:0]   ip_wb_dst,
    input  wire [63:0]  ip_wb_result,
    input  wire         ip_wb_wb_en,
    input  wire         ip_wb_valid,
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
    input  wire         lsp_unaligned_load,
    input  wire         lsp_unaligned_store,
    input  wire [63:0]  lsp_unaligned_epc,
    // Hazard detection & Bypassing
    input  wire         lsp_ix_mem_busy,
    input  wire         lsp_ix_mem_wb_en,
    input  wire [4:0]   lsp_ix_mem_dst,
    input  wire [4:0]   lsp_wb_dst,
    input  wire [63:0]  lsp_wb_result,
    input  wire         lsp_wb_wb_en,
    input  wire         lsp_wb_valid,
    // To muldiv unit
    output reg  [63:0]  ix_md_pc,
    output reg  [4:0]   ix_md_dst,
    output reg  [63:0]  ix_md_operand1,
    output reg  [63:0]  ix_md_operand2,
    output reg  [2:0]   ix_md_md_op,
    output reg          ix_md_muldiv,
    output reg          ix_md_valid,
    input  wire         ix_md_ready,
    // Hazard detection
    input  wire [4:0]   md_ix_dst,
    input  wire         md_ix_active,
    // To trap unit
    output reg  [63:0]  ix_trap_pc,
    output reg  [4:0]   ix_trap_dst,
    output reg  [1:0]   ix_trap_csr_op,
    output reg  [11:0]  ix_trap_csr_id,
    output reg  [63:0]  ix_trap_csr_opr,
    output reg          ix_trap_mret,
    output reg          ix_trap_int,
    output reg          ix_trap_intexc,
    output reg  [3:0]   ix_trap_cause,
    output reg          ix_trap_valid,
    input  wire         ix_trap_ready,
    input  wire [15:0]  trap_ix_ip,
    // Fence I
    output reg          im_invalidate_req,
    input  wire         im_invalidate_resp,
    output reg          dm_flush_req,
    input  wire         dm_flush_resp,
    output reg          ix_if_pc_override,
    output reg  [63:0]  ix_if_new_pc
);

    // Hazard detection
    assign rf_rsrc0 = dec_ix_rs1;
    assign rf_rsrc1 = dec_ix_rs2;
    wire [4:0] rf_rsrc [0:1];
    assign rf_rsrc[0] = rf_rsrc0;
    assign rf_rsrc[1] = rf_rsrc1;
    wire [63:0] rf_rdata [0:1];
    assign rf_rdata[0] = rf_rdata0;
    assign rf_rdata[1] = rf_rdata1;
    reg [0:0] rs_ready [0:1];
    reg [63:0] rs_val [0:1];
    wire ip_ex_ixstalled = ix_ip_valid && !ix_ip_ready && ix_ip_wb_en;
    wire ip_ex_active = ix_ip_valid && ix_ip_ready && ix_ip_wb_en;
    wire ip_wb_active = ip_wb_valid && ip_wb_wb_en;
    wire lsp_ag_active = ix_lsp_valid;
    wire lsp_mem_active = lsp_ix_mem_busy;
    wire lsp_wb_active = lsp_wb_valid && lsp_wb_wb_en;
    /* verilator lint_off UNUSED */
    reg dbg_stl_ipe [0:1];
    reg dbg_fwd_ipe [0:1];
    reg dbg_fwd_ipw [0:1];
    reg dbg_stl_lag [0:1];
    reg dbg_stl_lma [0:1];
    reg dbg_fwd_lwb [0:1];
    reg dbg_stl_mdi [0:1];
    reg dbg_stl_mda [0:1];
    /* verilator lint_on UNUSED */
    genvar i;
    generate
        for (i = 0; i < 2; i = i + 1) begin
            always @(*) begin
                dbg_stl_ipe[i] = 1'b0;
                dbg_fwd_ipe[i] = 1'b0;
                dbg_fwd_ipw[i] = 1'b0;
                dbg_stl_lag[i] = 1'b0;
                dbg_stl_lma[i] = 1'b0;
                dbg_fwd_lwb[i] = 1'b0;
                dbg_stl_mdi[i] = 1'b0;
                dbg_stl_mda[i] = 1'b0;

                rs_ready[i] = 1'b1;
                // Register read
                rs_val[i] = (rf_rsrc[i] == 5'd0) ? (64'd0) : rf_rdata[i];

                // Forwarding point: IP writeback
                if (ip_wb_active && (ip_wb_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = ip_wb_result;
                    dbg_fwd_ipw[i] = 1'b1;
                end
                // Forwarding point: IP execution
                if (ip_ex_active && (ix_ip_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = ip_ix_forwarding;
                    dbg_fwd_ipe[i] = 1'b1;
                end
                // Stall point: IP execution not accepted
                if (ip_ex_ixstalled && (ix_ip_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b0;
                    dbg_stl_ipe[i] = 1'b1;
                end

                // Forwarding point: LSP writeback
                if (lsp_wb_active && (lsp_wb_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = lsp_wb_result;
                    dbg_fwd_lwb[i] = 1'b1;
                end
                // Stall point: LSP memory access active
                if (lsp_ix_mem_wb_en && (lsp_ix_mem_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b0;
                    dbg_stl_lma[i] = 1'b1;
                end
                // Stall point: LSP address generation
                if (lsp_ag_active && ix_lsp_wb_en &&
                        (ix_lsp_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b0;
                    dbg_stl_lag[i] = 1'b1;
                end
                // Stall point: MD issue
                if (ix_md_valid && (ix_md_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b0;
                    dbg_stl_mdi[i] = 1'b1;
                end
                // Stall point: MD active
                if (md_ix_active && (md_ix_dst == rf_rsrc[i])) begin
                    rs_ready[i] = 1'b0;
                    dbg_stl_mda[i] = 1'b1;
                end

                // Always override to 0 in case write to 0 forwarding is valid
                if (rf_rsrc[i] == 5'd0) begin
                    rs_ready[i] = 1'b1;
                    rs_val[i] = 64'd0;
                end
            end
        end
    endgenerate

    // WAW hazard
    // TODO: If WB is accepted this cycle OR will be accepted next cycle,
    // then it's not a hazard
    wire waw_from_ip = (!dec_ix_wb_en) ||
            ((!ip_wb_active || (ip_wb_dst != dec_ix_rd)) &&
            (!ip_ex_active || (ix_ip_dst != dec_ix_rd)) &&
            (!ip_ex_ixstalled || (ix_ip_dst != dec_ix_rd)));
    // Warning: this doesn't check the case where LSP is ready for WB.
    // This is creates an edge case where is a load instruction destination is
    // also used for jal target register, and MD happens to be active for two
    // cycles (doesn't currently possible), a WAW condition happens.
    // When this ever becomes possible, WB stage needs provision to fix this.
    wire waw_from_lsp =
            (!lsp_ix_mem_wb_en || (lsp_ix_mem_dst != dec_ix_rd)) &&
            (!lsp_ag_active || !ix_lsp_wb_en || (ix_lsp_dst != dec_ix_rd));
    wire waw_from_md = (!ix_md_valid || (ix_md_dst != dec_ix_rd)) &&
            (!md_ix_active || (md_ix_dst != dec_ix_rd));
    // For LSP: It's only going to be faster than MD, only check md
    wire waw_lsp = waw_from_md;
    // For IP: It need to protect against LSP and MD
    wire waw_ip = waw_from_lsp && waw_from_md;
    // For MD: It need to protect against only LSP
    wire waw_md = waw_from_lsp;

    wire operand1_ready = (dec_ix_operand1 == `D_OPR1_RS1) ? rs_ready[0] : 1'b1;
    wire operand2_ready = (dec_ix_operand2 == `D_OPR2_RS2) ? rs_ready[1] : 1'b1;

    wire [63:0] operand1_value = ((dec_ix_operand1 == `D_OPR1_PC) ||
            (dec_ix_br_inj_pc)) ? (dec_ix_pc) :
            (dec_ix_operand1 == `D_OPR1_RS1) ? (rs_val[0]) :
            (dec_ix_operand1 == `D_OPR1_ZERO) ? (64'd0) :
            (dec_ix_operand1 == `D_OPR1_ZIMM) ? ({59'd0, dec_ix_rs1}) : (64'bx);
    wire [63:0] operand2_value =
            (dec_ix_operand2 == `D_OPR2_RS2) ? (rs_val[1]) :
            (dec_ix_operand2 == `D_OPR2_IMM) ? (dec_ix_imm) :
            (dec_ix_operand2 == `D_OPR2_4) ? (64'd4) : (64'bx);
    wire [63:0] br_base = (dec_ix_br_base_src == `BB_PC) ? (dec_ix_pc) :
            (rs_val[0]);

    // Trap instruction also blocks all proceeding instructions
    reg trap_ongoing;
    wire int_pending = (trap_ix_ip != 16'd0);
    wire exc_pending = (lsp_unaligned_load || lsp_unaligned_store);
    wire ix_opr_ready = operand1_ready && operand2_ready;
    wire ix_issue_common = (dec_ix_valid) && (ix_opr_ready) && !pipe_flush  &&
            !trap_ongoing && !int_pending && !exc_pending;
    wire ix_issue_ip0 = ix_issue_common && (ix_ip_ready) && (waw_ip) &&
            ((dec_ix_op_type == `OT_INT) || (dec_ix_op_type == `OT_BRANCH));
    wire ix_issue_lsp = ix_issue_common && (ix_lsp_ready) && (waw_lsp) &&
            ((dec_ix_op_type == `OT_LOAD) || (dec_ix_op_type == `OT_STORE));
    wire ix_issue_md = ix_issue_common && (ix_md_ready) && (waw_md) &&
            (dec_ix_op_type == `OT_MULDIV);
    wire ix_issue_trap = ix_issue_common && !trap_ongoing &&
            (dec_ix_op_type == `OT_TRAP) && ix_barrier_done; 
    // Wait for LS pipe to finish
    wire ix_fenced_done = !(lsp_ag_active || lsp_mem_active || lsp_wb_active);
    reg ix_fencei_done = 1'b0;
    wire ix_fence_done = (dec_ix_valid) &&
            (dec_ix_op_type == `OT_FENCE) && (ix_fenced_done) &&
            (!dec_ix_fencei || ix_fencei_done);
    // Wait for integer pipe to finish
    wire ix_ibarrier_done = !(ip_ex_ixstalled || ip_ex_active || ip_wb_active);
    // Barrier for waiting for in-flight instructions to complete
    wire ix_barrier_done = ix_fenced_done && ix_ibarrier_done;
    wire ix_issue =
            // Instructions to pipes
            ix_issue_ip0 || ix_issue_lsp || ix_issue_md || ix_issue_trap ||
            // Fake instruction for fence/ barrier
            ix_fence_done;

    wire dbg_stl_ip0waw = ix_issue_common && (ix_ip_ready) && (!waw_ip) &&
            ((dec_ix_op_type == `OT_INT) || (dec_ix_op_type == `OT_BRANCH));
    wire dbg_stl_lspwaw = ix_issue_common && (ix_lsp_ready) && (!waw_lsp) &&
            ((dec_ix_op_type == `OT_LOAD) || (dec_ix_op_type == `OT_STORE));
    wire dbg_stl_mdwaw = ix_issue_common && (ix_md_ready) && (!waw_md) &&
            (dec_ix_op_type == `OT_MULDIV);
    reg [63:0] dbg_stl_ip0waw_cntr;
    reg [63:0] dbg_stl_lspwaw_cntr;
    reg [63:0] dbg_stl_mdwaw_cntr;
    always @(posedge clk) begin
        if (rst) begin
            dbg_stl_ip0waw_cntr <= 0;
            dbg_stl_lspwaw_cntr <= 0;
            dbg_stl_mdwaw_cntr <= 0;
        end
        else begin
            dbg_stl_ip0waw_cntr <= dbg_stl_ip0waw_cntr + dbg_stl_ip0waw;
            dbg_stl_lspwaw_cntr <= dbg_stl_lspwaw_cntr + dbg_stl_lspwaw;
            dbg_stl_mdwaw_cntr <= dbg_stl_mdwaw_cntr + dbg_stl_mdwaw;
        end
    end

    wire ix_stall = dec_ix_valid && !ix_issue && !pipe_flush;
    assign dec_ix_ready = !rst && !ix_stall;

    // Fencei handling
    reg im_invalidate_done, dm_flush_done;
    always @(posedge clk) begin
        if ((!rst) && (dec_ix_valid) && (dec_ix_fencei) &&
                (!ix_fencei_done)) begin
            im_invalidate_req <= 1'b1;
            dm_flush_req <= 1'b1;
            im_invalidate_done <= 1'b0;
            dm_flush_done <= 1'b0;
            if (im_invalidate_resp == 1'b1) begin
                im_invalidate_req <= 1'b0;
                im_invalidate_done <= 1'b1;
            end
            if (dm_flush_resp == 1'b1) begin
                dm_flush_req <= 1'b0;
                dm_flush_done <= 1'b1;
            end
            if (dm_flush_done && im_invalidate_done) begin
                ix_if_pc_override <= 1'b1;
                ix_if_new_pc <= dec_ix_pc + 4;
                ix_fencei_done <= 1'b1;
            end
        end
        else begin
            ix_if_pc_override <= 1'b0;
            ix_if_new_pc <= 64'bx;
            ix_fencei_done <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (ix_issue_ip0) begin
            ix_ip_op <= dec_ix_op;
            ix_ip_option <= dec_ix_option;
            ix_ip_truncate <= dec_ix_truncate;
            ix_ip_br_type <= dec_ix_br_type;
            ix_ip_br_neg <= dec_ix_br_neg;
            ix_ip_br_offset <= dec_ix_imm[20:0];
            ix_ip_br_base <= br_base;
            ix_ip_operand1 <= operand1_value;
            ix_ip_operand2 <= operand2_value;
            ix_ip_bp <= dec_ix_bp;
            ix_ip_bt <= dec_ix_bt;
            ix_ip_wb_en <= dec_ix_wb_en;
            ix_ip_dst <= dec_ix_rd;
            ix_ip_pc <= dec_ix_pc;
            ix_ip_valid <= 1'b1;
        end
        else if (ix_ip_ready || pipe_flush) begin
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
        else if (ix_lsp_ready || pipe_flush) begin
            ix_lsp_valid <= 1'b0;
        end
        if (ix_issue_md) begin
            ix_md_pc <= dec_ix_pc;
            ix_md_dst <= dec_ix_rd;
            ix_md_operand1 <= operand1_value;
            ix_md_operand2 <= operand2_value;
            ix_md_md_op <= dec_ix_md_op;
            ix_md_muldiv <= dec_ix_muldiv;
            ix_md_valid <= 1'b1;
        end
        else if (ix_md_ready || pipe_flush) begin
            ix_md_valid <= 1'b0;
        end
        // Trap waits for all preceeding instructions to complete and blocks all
        // proceeding instructions, so it shouldn't be affected by pipe flush
        if (ix_issue_trap) begin
            ix_trap_pc <= dec_ix_pc;
            ix_trap_dst <= dec_ix_rd;
            ix_trap_csr_op <= dec_ix_csr_op;
            ix_trap_csr_id <= dec_ix_imm[11:0];
            ix_trap_csr_opr <= operand1_value;
            ix_trap_mret <= dec_ix_mret;
            ix_trap_int <= dec_ix_intr;
            ix_trap_intexc <= `MCAUSE_EXCEPTION;
            ix_trap_cause <= dec_ix_cause;
            ix_trap_valid <= 1'b1;
            trap_ongoing <= 1'b1;
        end
        else if (exc_pending) begin
            ix_trap_pc <= lsp_unaligned_epc;
            ix_trap_mret <= 1'b0;
            ix_trap_int <= 1'b1;
            ix_trap_intexc <= `MCAUSE_EXCEPTION;
            ix_trap_cause <=
                    (lsp_unaligned_load) ? (`MCAUSE_LMISALGN) :
                    (lsp_unaligned_store) ? (`MCAUSE_SMISALGN) : 4'bx;
            ix_trap_valid <= 1'b1;
            trap_ongoing <= 1'b1;
        end
        else if (int_pending) begin
            // Respond to interrupt
            ix_trap_pc <= dec_ix_pc;
            //ix_trap_dst <= 5'bx;
            //ix_trap_csr_op <= 2'bx;
            //ix_trap_csr_id <= 12'bx;
            //ix_trap_csr_opr <= 64'bx;
            ix_trap_mret <= 1'b0;
            ix_trap_int <= 1'b1;
            ix_trap_intexc <= `MCAUSE_INTERRUPT;
            ix_trap_cause <=
                    trap_ix_ip[`MIE_MSI] ? `MCAUSE_MSI :
                    trap_ix_ip[`MIE_MTI] ? `MCAUSE_MTI :
                    trap_ix_ip[`MIE_MEI] ? `MCAUSE_MEI : 4'bx;
            ix_trap_valid <= 1'b1;
            trap_ongoing <= 1'b1;
        end
        else if (ix_trap_ready) begin
            if (ix_trap_valid) begin
                ix_trap_valid <= 1'b0;
            end
            else begin
                trap_ongoing <= 1'b0;
            end
        end

        if (rst) begin
            ix_ip_valid <= 1'b0;
            ix_lsp_valid <= 1'b0;
            ix_md_valid <= 1'b0;
            ix_trap_valid <= 1'b0;
            trap_ongoing <= 1'b0;
        end
    end
endmodule
