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
`include "options.vh"

// Instruction fetching pipeline (dual issue)
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
    // dec1 higher address
    output wire [63:0]  if_dec1_pc,
    output wire [31:0]  if_dec1_instr,
    output wire         if_dec1_bp,
    output wire [1:0]   if_dec1_bp_track,
    output wire [63:0]  if_dec1_bt,
    output wire         if_dec1_valid,
    // dec0 lower address
    output wire [63:0]  if_dec0_pc,
    output wire [31:0]  if_dec0_instr,
    output wire         if_dec0_bp,
    output wire [1:0]   if_dec0_bp_track,
    output wire [63:0]  if_dec0_bt,
    output wire         if_dec0_valid,
    input  wire         if_dec_ready,
    // Next PC
    // Exception and CSR induced control flow change are not tracked by BP
    input  wire         ip_if_branch,
    input  wire         ip_if_branch_taken,
    input  wire [63:0]  ip_if_branch_pc,
    input  wire         ip_if_branch_is_call,
    input  wire         ip_if_branch_is_ret,
    input  wire [1:0]   ip_if_branch_track,
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
    wire ifp_stalled = ifp_stalled_memory_resp || ifp_stalled_back_pressure ||
            bp_init_active || btb_init_active;
    wire [63:0] ifp_new_pc;
    wire ifp_pc_override;

    wire next_valid = !ifp_stalled && !rst;
    wire ifp_memreq_handshaking = im_req_valid && im_req_ready;

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
        .b_ready(ifp_memreq_handshaking)
    );

    // Branch predictor
    wire bu_active = ifp_memreq_handshaking;

    // BTB
    // Valid PC: [31:2] // 30 bits
    // index: 5 bits, tag: 25 bits, target address: 30 bits, valid 1 bit
    // total: 56 bit x 2 = 112 bit
    wire [`BTB_ABITS-1:0] btb_index_lo = {next_pc[`BTB_ABITS+1:3], 1'b0};
    wire [`BTB_ABITS-1:0] btb_index_hi = {next_pc[`BTB_ABITS+1:3], 1'b1};
    reg [55:0] btb_rd_lo;
    reg [55:0] btb_rd_hi;

    reg btb_init_active = 1'b0;
    reg [`BTB_ABITS-1:0] btb_init_index;
    always @(posedge clk) begin
        // BTB initializer
        if (btb_init_active) begin
            if (btb_init_index == `BTB_DEPTH - 1)
                btb_init_active <= 1'b0;
            btb_init_index <= btb_init_index + 1;
        end
        if (rst) begin
            btb_init_active <= 1'b1;
            btb_init_index <= 0;
        end
    end

    wire [`BTB_ABITS-1:0] btb_wr_index = (btb_init_active) ? (btb_init_index) :
            (ip_if_branch_pc[`BTB_ABITS+1:2]);
    wire [55:0] btb_wr_data = (btb_init_active) ? (56'd0) :
            ({1'b1, ip_if_branch_pc[31:7], if_new_pc[31:2]});
    wire btb_wr_en = (btb_init_active) ? (1'b1) :
            (ip_if_branch && ip_if_branch_taken);

    reg [55:0] btb_mem [0:`BTB_DEPTH-1];

    always @(posedge clk) begin
        if (!rst) begin
            if (btb_wr_en) begin
                btb_mem[btb_wr_index] <= btb_wr_data;
            end
            
            if (bu_active) begin
                btb_rd_lo <= btb_mem[btb_index_lo];
                btb_rd_hi <= btb_mem[btb_index_hi];
            end
        end
    end

    `ifdef BPU_ALWAYS_NOT_TAKEN
    wire bp_result_hi = `BP_NOT_TAKEN;
    wire bp_result_lo = `BP_NOT_TAKEN;
    wire bp_init_active = 0;
    wire [1:0] bp_track_hi = 2'b0;
    wire [1:0] bp_track_lo = 2'b0;
    `elsif BPU_ALWAYS_TAKEN
    wire bp_result_hi = `BP_TAKEN;
    wire bp_result_lo = `BP_TAKEN;
    wire bp_init_active = 0;
    wire [1:0] bp_track_hi = 2'b0;
    wire [1:0] bp_track_lo = 2'b0;
    `elsif BPU_GLOBAL
    // BP initializer
    reg bp_init_active = 1'b0;
    reg [`BHT_MEM_ABITS-1:0] bp_init_index;
    always @(posedge clk) begin
        // BP table initializer
        if (bp_init_active) begin
            if (bp_init_index == `BHT_MEM_DEPTH - 1)
                bp_init_active <= 1'b0;
            bp_init_index <= bp_init_index + 1;
        end
        if (rst) begin
            bp_init_active <= 1'b1;
            bp_init_index <= 0;
        end
    end

    // Global history register
    `ifdef BPU_GHR_WIDTH
    reg [`BPU_GHR_WIDTH-1:0] branch_history_actual;
    reg [`BPU_GHR_WIDTH-1:0] branch_history_speculative;
    wire [`BPU_GHR_WIDTH-1:0] branch_history_speculative_next =
            (ip_if_branch && if_pc_override) ?
                {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken} :
            (bu_active && !ifp_pc_override &&
                    ((f2_dec0_valid && insn0_is_branch) ||
                    (f2_dec1_valid && insn1_is_branch))) ?
                {branch_history_speculative[`BPU_GHR_WIDTH-2:0], f1_bp} :
            branch_history_speculative;
    // Speculative history
    always @(posedge clk) begin
        if (ip_if_branch) begin
            branch_history_actual <=
                {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken};
            /*$display("Update actual branch history to %b", {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken});
            if (if_pc_override)
                $display("Branch mispredicted");*/
        end

        branch_history_speculative <= branch_history_speculative_next;
        //$display("Speculate branch history to %b", branch_history_speculative_next);

        if (rst) begin
            branch_history_actual <= 0;
            branch_history_speculative <= 0;
        end
    end

    // If the BPU needs to make a prediction for the newly overriden PC
    // It should use the actual branch history (snapshot of where it's overriden)
    // instead of the speculated latest version.
    wire [`BPU_GHR_WIDTH-1:0] branch_history_r = (ip_if_branch && if_pc_override) ?
            branch_history_actual : branch_history_speculative_next;
    wire [`BPU_GHR_WIDTH-1:0] branch_history_w = branch_history_actual;

    `endif

    `ifdef BPU_GHR_WIDTH
    wire [`BHT_ABITS-1:0] bp_gsh_update_index =
            {branch_history_w[`BHT_ABITS-2:0], 1'b0} ^ ip_if_branch_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_gsh_index =
            {branch_history_r[`BHT_ABITS-2:0], 1'b0} ^ next_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_gsl_update_index =
            {branch_history_w, ip_if_branch_pc[`BHT_ABITS+1-`BPU_GHR_WIDTH:2]};
    wire [`BHT_ABITS-1:0] bp_gsl_index =
            {branch_history_r, next_pc[`BHT_ABITS+1-`BPU_GHR_WIDTH:2]};
    `endif
    wire [`BHT_ABITS-1:0] bp_bm_update_index = ip_if_branch_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_bm_index = next_pc[`BHT_ABITS+1:2];

    `ifdef BPU_GLOBAL_GSHARE
    wire [`BHT_ABITS-1:0] bp_update_index = bp_gsh_update_index;
    wire [`BHT_ABITS-1:0] bp_index = bp_gsh_index;
    `elsif BPU_GLOBAL_GSELECT
    wire [`BHT_ABITS-1:0] bp_update_index = bp_gsl_update_index;
    wire [`BHT_ABITS-1:0] bp_index = bp_gsl_index;
    `elsif BPU_GLOBAL_BIMODAL
    wire [`BHT_ABITS-1:0] bp_update_index = bp_bm_update_index;
    wire [`BHT_ABITS-1:0] bp_index = bp_bm_index;
    `endif

`ifdef BPU_TOURNAMENT
    // Tournament predictor
    // P1 use Bimodal, P2 use GSHARE
    wire [`BHT_ABITS-1:0] bp_p1_update_index = bp_bm_update_index;
    wire [`BHT_ABITS-1:0] bp_p1_index = bp_bm_index;
    wire [`BHT_ABITS-1:0] bp_p2_update_index = bp_gsh_update_index;
    wire [`BHT_ABITS-1:0] bp_p2_index = bp_gsh_index;
    
    wire [1:0] bp_p1_counter_hi;
    wire [1:0] bp_p1_counter_lo;
    wire [1:0] bp_p2_counter_hi;
    wire [1:0] bp_p2_counter_lo;

    bp_base p1(
        .clk(clk),
        .rst(rst),
        .bp_active(bu_active),
        .bp_update(ip_if_branch),
        .bp_update_taken(ip_if_branch_taken),
        .bp_init_active(bp_init_active),
        .bp_init_index(bp_init_index),
        .bp_index(bp_p1_index),
        .bp_update_index(bp_p1_update_index),
        .bp_counter_hi(bp_p1_counter_hi),
        .bp_counter_lo(bp_p1_counter_lo)
    );

    bp_base p2(
        .clk(clk),
        .rst(rst),
        .bp_active(bu_active),
        .bp_update(ip_if_branch),
        .bp_update_taken(ip_if_branch_taken),
        .bp_init_active(bp_init_active),
        .bp_init_index(bp_init_index),
        .bp_index(bp_p2_index),
        .bp_update_index(bp_p2_update_index),
        .bp_counter_hi(bp_p2_counter_hi),
        .bp_counter_lo(bp_p2_counter_lo)
    );

    // Selector
    wire [`BHT_ABITS-1:0] bp_sel_update_index = ip_if_branch_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_sel_index = next_pc[`BHT_ABITS+1:2];
    wire bp_sel_update;
    wire bp_sel_update_val; // 0 - leaning towards P1, 1 - leaning towards P2
    
    wire [1:0] bp_sel_counter_hi;
    wire [1:0] bp_sel_counter_lo;
    bp_base bp_selector (
        .clk(clk),
        .rst(rst),
        .bp_active(bu_active),
        .bp_update(bp_sel_update),
        .bp_update_taken(bp_sel_update_val),
        .bp_init_active(bp_init_active),
        .bp_init_index(bp_init_index),
        .bp_index(bp_sel_index),
        .bp_update_index(bp_sel_update_index),
        .bp_counter_hi(bp_sel_counter_hi),
        .bp_counter_lo(bp_sel_counter_lo)
    );

    /*always @(posedge clk) begin
        if (ip_if_branch) begin
            if (bp_p1_correct) begin
                $display("P1 was correct");
            end
            else begin
                $display("P1 was incorrect");
            end
            if (bp_p2_correct) begin
                $display("P2 was correct");
            end
            else begin
                $display("P2 was incorrect");
            end
            if (bp_sel_update) begin
                $display("Updating selector to %d from %b", bp_sel_update_val, ip_if_branch_track);
            end
            else begin
                $display("Not updating selector from %b", ip_if_branch_track);
            end
        end
    end*/

    // Update when predictors results diverge
    assign bp_sel_update = ip_if_branch &&
            ((ip_if_branch_track != 2'b00) && (ip_if_branch_track != 2'b11));
    wire bp_p1_correct = ip_if_branch_track[1] == ip_if_branch_taken;
    wire bp_p2_correct = ip_if_branch_track[0] == ip_if_branch_taken;
    assign bp_sel_update_val = bp_p2_correct; // Used only when results diverge

    wire [1:0] bp_counter_hi = bp_sel_counter_hi[1] ?
            bp_p2_counter_hi : bp_p1_counter_hi;
    wire [1:0] bp_counter_lo = bp_sel_counter_lo[1] ?
            bp_p2_counter_lo : bp_p1_counter_lo;
    /*wire [1:0] bp_counter_hi = bp_p2_counter_hi;
    wire [1:0] bp_counter_lo = bp_p2_counter_lo;*/
    wire bp_result_hi = bp_counter_hi[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire bp_result_lo = bp_counter_lo[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire [1:0] bp_track_hi = {bp_p1_counter_hi[1], bp_p2_counter_hi[1]};
    wire [1:0] bp_track_lo = {bp_p1_counter_lo[1], bp_p2_counter_lo[1]};

    `else

    wire [1:0] bp_counter_hi;
    wire [1:0] bp_counter_lo;
    bp_base bp(
        .clk(clk),
        .rst(rst),
        .bp_active(bu_active),
        .bp_update(ip_if_branch),
        .bp_update_taken(ip_if_branch_taken),
        .bp_init_active(bp_init_active),
        .bp_init_index(bp_init_index),
        .bp_index(bp_index),
        .bp_update_index(bp_update_index),
        .bp_counter_hi(bp_counter_hi),
        .bp_counter_lo(bp_counter_lo)
    );
    wire bp_result_hi = bp_counter_hi[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire bp_result_lo = bp_counter_lo[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire [1:0] bp_track_hi = 2'b0;
    wire [1:0] bp_track_lo = 2'b0;
    `endif

    `endif


    // Return Address Stack
    reg [31:2] ras [0:`RAS_DEPTH-1];
    reg [`RAS_DEPTH_BITS-1:0] ras_ptr_actual;
    reg [`RAS_DEPTH_BITS-1:0] ras_ptr_speculative;
    wire [`RAS_DEPTH_BITS-1:0] ras_ptr_actual_next =
            (ip_if_branch_is_call) ? (ras_ptr_actual + 1) :
            (ip_if_branch_is_ret) ? (ras_ptr_actual - 1) : (ras_ptr_actual);
    reg [`RAS_DEPTH_BITS:0] ras_level_actual;
    reg [`RAS_DEPTH_BITS:0] ras_level_speculative;
    wire [`RAS_DEPTH_BITS:0] ras_level_actual_next =
            (ip_if_branch_is_call) ? (
                (ras_level_actual != `RAS_DEPTH) ?
                (ras_level_actual + 1) : (ras_level_actual)) :
            (ip_if_branch_is_ret) ? (
                (ras_level_actual != 0) ?
                (ras_level_actual - 1) : (ras_level_actual)) :
            (ras_level_actual);
    always @(posedge clk) begin
        if (ip_if_branch) begin
            ras_ptr_actual <= ras_ptr_actual_next;
            ras_level_actual <= ras_level_actual_next;
        end

        if (ip_if_branch && if_pc_override) begin
            // RAS mispredict, correct back to actual
            ras_ptr_speculative <= ras_ptr_actual_next;
            if (ip_if_branch_is_call)
                ras[ras_ptr_actual + 1] <= ip_if_branch_pc[31:2] + 1;
            ras_level_speculative <= ras_level_actual_next;
        end
        else if (bu_active && !ifp_pc_override) begin
            if (insn0_is_call && f2_dec0_valid) begin
                ras[ras_ptr_speculative + 1] <= f2_pc_aligned_plus_4[31:2];
                ras_ptr_speculative <= ras_ptr_speculative + 1;
                if (ras_level_speculative != `RAS_DEPTH)
                    ras_level_speculative <= ras_level_speculative + 1;
                else
                    $display("RAS overflow");
            end
            else if (insn0_is_ret && f2_dec0_valid) begin
                ras_ptr_speculative <= ras_ptr_speculative - 1;
                if (ras_level_speculative != 0)
                    ras_level_speculative <= ras_level_speculative - 1;
            end
            else if (insn1_is_call && f2_dec1_valid) begin
                ras[ras_ptr_speculative + 1] <= aligned_pc_plus_8[31:2];
                ras_ptr_speculative <= ras_ptr_speculative + 1;
                if (ras_level_speculative != `RAS_DEPTH)
                    ras_level_speculative <= ras_level_speculative + 1;
                else
                    $display("RAS overflow");
            end
            else if (insn1_is_ret && f2_dec1_valid) begin
                ras_ptr_speculative <= ras_ptr_speculative - 1;
                if (ras_level_speculative != 0)
                    ras_level_speculative <= ras_level_speculative - 1;
            end
        end

        if (rst) begin
            ras_ptr_actual <= 0;
            ras_ptr_speculative <= 0;
            ras_level_actual <= 0;
            ras_level_speculative <= 0;
        end
    end

    wire ras_hit_lo = insn0_is_ret_buf && f2_dec0_valid && (ras_level_speculative != 0);
    wire ras_hit_hi = insn1_is_ret_buf && f2_dec1_valid && (ras_level_speculative != 0);

    wire [63:0] ras_result = {32'b0, ras[ras_ptr_speculative], 2'b0};

    wire [63:0] btb_result_lo = {32'b0, btb_rd_lo[29:0], 2'b0};
    wire [63:0] btb_result_hi = {32'b0, btb_rd_hi[29:0], 2'b0};
    wire btb_hit_lo = btb_rd_lo[55] && (btb_rd_lo[54:30] == f1_f2_pc[31:7]) &&
            !btb_init_active;
    wire btb_hit_hi = btb_rd_hi[55] && (btb_rd_hi[54:30] == f1_f2_pc[31:7]) &&
            !btb_init_active;

    // Branch if BTB hit and BP says taken 
    wire f1_bp_lo = (bp_result_lo == `BP_TAKEN) && (btb_hit_lo) && !f1_f2_pc[2];
    wire f1_bp_hi = (bp_result_hi == `BP_TAKEN) && (btb_hit_hi);
    wire f1_bp = insn_both_branch ? f1_bp_lo : (f1_bp_hi || f1_bp_lo);

    /*always @(posedge clk) begin
        if (bu_active) begin
            if (ifp_pc_override) begin
                //
            end
            else if (ras_hit_lo) begin
                $display("PC %08x RAS hit, next PC %08x", f2_pc_aligned, ras_result);
            end
            else if (f1_bp_lo && f2_dec0_valid) begin
                $display("PC %08x predict branch taken, next PC %08x (%d, %b)",
                f2_pc_aligned, btb_result_lo, bp_result_lo, bp_track_lo);
            end
            else if (insn_both_branch) begin
                $display("PC %08x both instruction are branches and first NT, restarting at %08x (%d ,%b)",
                f2_pc_aligned, f2_pc_aligned_plus_4, bp_counter_lo, bp_track_lo);
            end
            else if (ras_hit_hi) begin
                $display("PC %08x RAS hit, next PC %08x", f2_pc_aligned_plus_4, ras_result);
            end
            else if (f1_bp_hi && f2_dec1_valid) begin
                $display("PC %08x predict branch taken, next PC %08x (%d, %b)",
                f2_pc_aligned_plus_4, btb_result_hi, bp_counter_hi, bp_track_hi);
            end
            else if (insn0_is_branch && f2_dec0_valid) begin
                $display("PC %08x predict branch not taken (%d, %b)",
                f2_pc_aligned, bp_counter_lo, bp_track_lo);
            end
            else if (insn1_is_branch && f2_dec1_valid) begin
                $display("PC %08x predict branch not taken (%d, %b)",
                f2_pc_aligned_plus_4, bp_counter_hi, bp_track_hi);
            end
        end

        if (ip_if_branch) begin
            if (ip_if_branch_taken)
                $display("!PC %08x branch taken", ip_if_branch_pc);
            else
                $display("!PC %08x branch not taken", ip_if_branch_pc);
        end
    end*/

    wire [63:0] pc_plus_4 = f1_f2_pc + 4;
    wire [63:0] aligned_pc_plus_8 = {f1_f2_pc[63:3], 3'b0} + 8;
    assign next_pc =
            (ifp_pc_override) ? (ifp_new_pc) : // mis-predict
            (ras_hit_lo) ? (ras_result) :
            (f1_bp_lo) ? (btb_result_lo) :
            // If both are branch, and valid (PC aligned to 8, insn0 valid)
            (insn_both_branch) ? (f2_pc_aligned_plus_4) :
            (ras_hit_hi) ? (ras_result) :
            (f1_bp_hi) ? (btb_result_hi) :
            (aligned_pc_plus_8); // PC incr

    always @(posedge clk) begin
        // Continue only if pipeline is not stalled
        if (!ifp_stalled_memory_resp) begin
            f1_f2_valid <= im_req_valid && im_req_ready;
        end
        if (ifp_memreq_handshaking) begin
            f1_f2_pc <= next_pc;
        end

        if (rst) begin
            f1_f2_pc <= RESET_VECTOR - 4;
            f1_f2_valid <= 1'b0;
        end
    end

    assign im_req_valid = next_valid;
    assign im_req_addr = next_pc;

    // F2: Imem result
    wire [63:0] f2_pc_aligned = {f1_f2_pc[63:3], 3'b0};
    wire [63:0] f2_pc_aligned_plus_4 = f2_pc_aligned + 4;

    wire [63:0] f2_dec1_pc = f2_pc_aligned_plus_4;
    wire [31:0] f2_dec1_instr = im_resp_rdata[63:32];
    wire f2_dec1_bp = f1_bp_hi;
    wire [1:0] f2_dec1_bp_track = bp_track_hi;
    wire [63:0] f2_dec1_bt = next_pc;
    // Higher instruction is valid if lower branch NT and not both are branch
    wire f2_dec1_valid = !f1_bp_lo && !ras_hit_lo && !insn_both_branch;

    wire [63:0] f2_dec0_pc = f2_pc_aligned;
    wire [31:0] f2_dec0_instr = im_resp_rdata[31:0];
    wire f2_dec0_bp = f1_bp_lo;
    wire [1:0] f2_dec0_bp_track = bp_track_lo;
    wire [63:0] f2_dec0_bt = (ras_hit_lo || f1_bp_lo) ? (next_pc) : (f2_pc_aligned_plus_4);
    wire f2_dec0_valid = !f1_f2_pc[2]; // Low instruction is valid only if aligned

    wire insn1_is_bcond = f2_dec1_instr[6:0] == `OP_BRANCH;
    wire insn1_is_jal = f2_dec1_instr[6:0] == `OP_JAL;
    wire insn1_is_jalr = f2_dec1_instr[6:0] == `OP_JALR;
    wire insn1_is_branch = insn1_is_bcond || insn1_is_jal || insn1_is_jalr;
    wire insn1_is_call = f2_dec1_instr[11:0] == 12'h0ef; // jal ra, xx or jalr ra, xx
    wire insn1_is_ret = f2_dec1_instr == 32'h00008067; // jalr zero, ra

    wire insn0_is_bcond = f2_dec0_instr[6:0] == `OP_BRANCH;
    wire insn0_is_jal = f2_dec0_instr[6:0] == `OP_JAL;
    wire insn0_is_jalr = f2_dec0_instr[6:0] == `OP_JALR;
    wire insn0_is_branch = insn0_is_bcond || insn0_is_jal || insn0_is_jalr;
    wire insn0_is_call = f2_dec0_instr[11:0] == 12'h0ef; // jal ra, xx or jalr ra, xx
    wire insn0_is_ret = f2_dec0_instr == 32'h00008067; // jalr zero, ra

    // Need to buffer insn_is_ret in case the memory takes more cycle to response
    // next request
    wire insn0_is_ret_buf, insn0_is_branch_buf, insn1_is_ret_buf, insn1_is_branch_buf;
    fifo_1d_fwft #(.WIDTH(4)) if_insn_type_buffer(
        .clk(clk),
        .rst(rst),
        .a_data({insn0_is_ret, insn0_is_branch, insn1_is_ret, insn1_is_branch}),
        .a_valid(im_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .b_data({insn0_is_ret_buf, insn0_is_branch_buf, insn1_is_ret_buf, insn1_is_branch_buf}),
        .b_valid(),
        .b_ready(im_req_ready)
    );

    wire insn_both_branch = insn0_is_branch_buf && insn1_is_branch_buf && !f1_f2_pc[2];

    wire fifo_valid;
    wire if_dec1_valid_fifo;
    wire if_dec0_valid_fifo;

    fifo_2d #(.WIDTH(328)) if_fifo (
        .clk(clk),
        .rst(rst || ifp_pc_override),
        .a_data({
                f2_dec1_pc, f2_dec1_instr, f2_dec1_bp, f2_dec1_bp_track,
                f2_dec1_bt, f2_dec1_valid,
                f2_dec0_pc, f2_dec0_instr, f2_dec0_bp, f2_dec0_bp_track,
                f2_dec0_bt, f2_dec0_valid}),
        .a_valid(im_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .a_almost_full(fifo_bp),
        .b_data({
                if_dec1_pc, if_dec1_instr, if_dec1_bp, if_dec1_bp_track,
                if_dec1_bt, if_dec1_valid_fifo,
                if_dec0_pc, if_dec0_instr, if_dec0_bp, if_dec0_bp_track,
                if_dec0_bt, if_dec0_valid_fifo}),
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

    assign if_dec1_valid = fifo_valid && if_dec1_valid_fifo;
    assign if_dec0_valid = fifo_valid && if_dec0_valid_fifo;

endmodule
