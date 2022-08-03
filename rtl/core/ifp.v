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
    output wire [1:0]   if_dec_bp_track,
    output wire [63:0]  if_dec_bt,
    output wire         if_dec_valid,
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
    reg ifp_stalled_last;
    wire [63:0] ifp_new_pc;
    wire ifp_pc_override;
    wire ifp_memreq_nack = im_req_valid && !im_req_ready;
    reg ifp_memreq_nack_last;

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

    wire bu_active = im_req_ready && im_req_valid;

    // BTB
    // Valid PC: [31:2] // 30 bits
    // index: 5 bits, tag: 25 bits, target address: 30 bits, valid 1 bit
    // total: 56 bit
    wire [`BTB_ABITS-1:0] btb_index = next_pc[`BTB_ABITS+1:2];
    wire [55:0] btb_rd;

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

    /*always @(posedge clk) begin
        if (btb_wr_en) begin
            $display("BTB index %d update to %014x", btb_wr_index, btb_wr_data);
        end
    end*/

    /*ram_32_56 btb_ram(
        .clk(clk),
        .rst(rst),
        .raddr(btb_index),
        .re(bu_active),
        .rd(btb_rd), // 1 cycle later
        .waddr(btb_wr_index),
        .wr(btb_wr_data),
        .we(btb_wr_en)
    );*/

    ram_customize #(.DBITS(56), .ABITS(`BTB_ABITS)) btb_ram(
        .clk(clk),
        .rst(rst),
        .addr0(btb_wr_index),
        .re0(1'b0),
        .rd0(),
        .wr0(btb_wr_data),
        .we0(btb_wr_en),
        .addr1(btb_index),
        .re1(bu_active),
        .rd1(btb_rd)
    );


    wire insn_is_bcond = im_instr[6:0] == `OP_BRANCH;
    wire insn_is_jal = im_instr[6:0] == `OP_JAL;
    wire insn_is_jalr = im_instr[6:0] == `OP_JALR;
    wire insn_is_branch = insn_is_bcond || insn_is_jal || insn_is_jalr;
    wire insn_is_call = im_instr[11:0] == 12'h0ef; // jal ra, xx or jalr ra, xx
    wire insn_is_ret = im_instr == 32'h00008067; // jalr zero, ra

    // Exteremely simple BPU
    `ifdef BPU_ALWAYS_NOT_TAKEN
    wire bp_result = `BP_NOT_TAKEN;
    wire bp_init_active = 0;
    wire [1:0] bp_track = 2'b0;
    `elsif BPU_ALWAYS_TAKEN
    wire bp_result = `BP_TAKEN;
    wire bp_init_active = 0;
    wire [1:0] bp_track = 2'b0;
    `elsif BPU_SIMPLE
    wire bp_init_active = 0;
    reg [1:0] bp_counter;
    wire [1:0] bp_counter_inc = (bp_counter == 2'b11) ? 2'b11 : bp_counter + 1;
    wire [1:0] bp_counter_dec = (bp_counter == 2'b00) ? 2'b00 : bp_counter - 1;
    always @(posedge clk) begin
        if (rst) begin
            bp_counter <= 2'b01;
        end
        else begin
            if (ip_if_branch) begin
                bp_counter <= (ip_if_branch_taken) ?
                        bp_counter_inc : bp_counter_dec;
            end
        end
    end
    wire bp_result = bp_counter[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire [1:0] bp_track = 2'b0;
    `elsif BPU_GLOBAL
    // BP initializer
    reg bp_init_active = 1'b0;
    reg [`BHT_ABITS-1:0] bp_init_index;
    always @(posedge clk) begin
        // BP table initializer
        if (bp_init_active) begin
            if (bp_init_index == `BHT_DEPTH - 1)
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
    // Speculative history
    always @(posedge clk) begin
        if (ip_if_branch) begin
            branch_history_actual <=
                {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken};
            //$display("Update actual branch history to %b", {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken});
        end

        if (bu_active) begin
            if (ip_if_branch && if_pc_override) begin
                // Mispredicted, correct speculation back to 1 step
                branch_history_speculative <=
                    {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken};
                //$display("Correct branch history to %b", {branch_history_actual[`BPU_GHR_WIDTH-2:0], ip_if_branch_taken});
            end
            else if (insn_is_branch) begin
                // Speculatively update BHR if the instruction is a branch
                branch_history_speculative <=
                    {branch_history_speculative[`BPU_GHR_WIDTH-2:0], f1_bp};
                //$display("Speculate branch history to %b", {branch_history_speculative[`BPU_GHR_WIDTH-2:0], f1_bp});
            end
        end

        if (rst) begin
            branch_history_actual <= 0;
            branch_history_speculative <= 0;
        end
    end

    // If the BPU needs to make a prediction for the newly overriden PC
    // It should use the actual branch history (snapshot of where it's overriden)
    // instead of the speculated latest version.
    wire [`BPU_GHR_WIDTH-1:0] branch_history_r = (ip_if_branch && if_pc_override) ?
            branch_history_actual : branch_history_speculative;
    wire [`BPU_GHR_WIDTH-1:0] branch_history_w = branch_history_actual;

    `endif

    `ifdef BPU_GHR_WIDTH
    wire [`BHT_ABITS-1:0] bp_gsh_update_index =
            branch_history_w ^ ip_if_branch_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_gsh_index =
            branch_history_r ^ next_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_gsl_update_index =
            {branch_history_w, ip_if_branch_pc[`BHT_ABITS+1-`BPU_GHR_WIDTH:2]};
    wire [`BHT_ABITS-1:0] bp_gsl_index =
            {branch_history_r, next_pc[`BHT_ABITS+1-`BPU_GHR_WIDTH:2]};
    `endif
    wire [`BHT_ABITS-1:0] bp_bm_update_index = ip_if_branch_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_bm_index = next_pc[`BHT_ABITS+1:2];

    `ifdef BPU_TOURNAMENT
    // Tournament predictor
    // P1 use Bimodal, P2 use GSHARE
    wire [`BHT_ABITS-1:0] bp_p1_update_index = bp_bm_update_index;
    wire [`BHT_ABITS-1:0] bp_p1_index = bp_bm_index;
    wire [`BHT_ABITS-1:0] bp_p2_update_index = bp_gsh_update_index;
    wire [`BHT_ABITS-1:0] bp_p2_index = bp_gsh_index;
    
    wire [1:0] bp_p1_counter;
    wire [1:0] bp_p2_counter;

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
        .bp_counter(bp_p1_counter)
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
        .bp_counter(bp_p2_counter)
    );

    // Selector
    wire [`BHT_ABITS-1:0] bp_sel_update_index = ip_if_branch_pc[`BHT_ABITS+1:2];
    wire [`BHT_ABITS-1:0] bp_sel_index = next_pc[`BHT_ABITS+1:2];
    wire bp_sel_update;
    wire bp_sel_update_val; // 0 - leaning towards P1, 1 - leaning towards P2
    
    wire [1:0] bp_sel_counter;
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
        .bp_counter(bp_sel_counter)
    );

    /*always @(posedge clk) begin
        if (bu_active && insn_is_branch) begin
            $display("PC %08x predicted to be %d %d, selecting %d with %d",
                f1_f2_pc, bp_p1_counter, bp_p2_counter, selected_counter, bp_sel_counter);
        end

        if (ip_if_branch) begin
            if (ip_if_branch_taken)
                $display("PC %08x branch taken", ip_if_branch_pc);
            else
                $display("PC %08x branch not taken", ip_if_branch_pc);
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

    wire [1:0] selected_counter = bp_sel_counter[1] ?
            bp_p2_counter : bp_p1_counter;
    wire bp_result = selected_counter[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire [1:0] bp_track = {bp_p1_counter[1], bp_p2_counter[1]};

    `else
    // Single predictor
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

    wire [1:0] bp_counter;
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
        .bp_counter(bp_counter)
    );
    wire bp_result = bp_counter[1] ? `BP_TAKEN : `BP_NOT_TAKEN;
    wire [1:0] bp_track = 2'b0;
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

        if (bu_active) begin
            if (ip_if_branch && if_pc_override) begin
                // RAS mispredict, correct back to actual
                ras_ptr_speculative <= ras_ptr_actual_next;
                ras[ras_ptr_actual + 1] <= pc_plus_4[31:2];
                ras_level_speculative <= ras_level_actual_next;
            end
            else if (insn_is_call) begin
                ras[ras_ptr_speculative + 1] <= pc_plus_4[31:2];
                ras_ptr_speculative <= ras_ptr_speculative + 1;
                if (ras_level_speculative != `RAS_DEPTH)
                    ras_level_speculative <= ras_level_speculative + 1;
                else
                    $display("RAS overflow");
            end
            else if (insn_is_ret) begin
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

    // Need to buffer insn_is_ret in case the memory takes more cycle to response
    // next request
    wire insn_is_ret_buf;
    fifo_1d_fwft #(.WIDTH(1)) if_insn_ret_buffer(
        .clk(clk),
        .rst(rst),
        .a_data(insn_is_ret),
        .a_valid(im_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .b_data(insn_is_ret_buf),
        .b_valid(),
        .b_ready(im_req_ready)
    );

    wire ras_hit = (insn_is_ret_buf) && (ras_level_speculative != 0);
    wire [63:0] ras_result = {32'b0, ras[ras_ptr_speculative], 2'b0};

    

    // TODO: Handle cases where an ifencei or something else happend so the
    // instruction at a certain PC is no longer a branch. This should be
    // corrected somewhere.
    wire [63:0] btb_result = {32'b0, btb_rd[29:0], 2'b0};
    wire btb_hit = btb_rd[55] && (btb_rd[54:30] == f1_f2_pc[31:7]) && !btb_init_active;
    // Branch if BTB hit, and BP says taken or it's unconditional branch
    wire f1_bp = (bp_result == `BP_TAKEN) && (btb_hit);

    /*always @(posedge clk) begin
        if (bu_active && btb_hit) begin
            $display("BTB PC %08x hit with %014x", f1_f2_pc, btb_rd);
        end
    end

    always @(negedge clk) begin
        $display(""); // newline
    end*/
    wire [63:0] pc_plus_4 = f1_f2_pc + 4;
    assign next_pc =
            (ifp_pc_override) ? (ifp_new_pc) : // mis-predict
            (ras_hit) ? (ras_result) : // RAS result
            (f1_bp) ? (btb_result) : // predicted branch
            (pc_plus_4); // PC incr

    always @(posedge clk) begin
        // Continue only if pipeline is not stalled
        if (!ifp_stalled_memory_resp) begin
            f1_f2_valid <= im_req_valid && im_req_ready;
        end
        if (next_valid && !ifp_memreq_nack) begin
            f1_f2_pc <= next_pc;
        end

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

    fifo_2d #(.WIDTH(164)) if_fifo (
        .clk(clk),
        .rst(rst || ifp_pc_override),
        .a_data({im_instr, f1_f2_pc, bp_result, bp_track, next_pc, ifp_pc_override}),
        .a_valid(im_resp_valid),
        /* verilator lint_off PINCONNECTEMPTY */
        .a_ready(),
        /* verilator lint_on PINCONNECTEMPTY */
        .a_almost_full(fifo_bp),
        .b_data({if_dec_instr, if_dec_pc, if_dec_bp, if_dec_bp_track, if_dec_bt, if_dec_pc_override}),
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
