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
module bp_base(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     bp_active,
    input  wire                     bp_update,
    input  wire                     bp_update_taken, // Taken - Inc, NT - Dec
    input  wire                     bp_init_active,
    input  wire [`BHT_ABITS-1:0]    bp_init_index,
    input  wire [`BHT_ABITS-1:0]    bp_index,
    input  wire [`BHT_ABITS-1:0]    bp_update_index,
    output wire [1:0]               bp_counter
);

    wire [`BHT_ABITS-1:0] bp_wr_index;
    wire [1:0] bp_wr_data;
    wire bp_wr_en;
    wire [1:0] bp_update_counter;
    wire bp_update_ren;
    /*ram_4096_2 bpu_ram(*/
    ram_customize #(.DBITS(2), .ABITS(`BHT_ABITS)) bpu_ram(
        .clk(clk),
        .rst(rst),
        .addr0(bp_wr_index),
        .re0(bp_update_ren),
        .rd0(bp_update_counter),
        .wr0(bp_wr_data),
        .we0(bp_wr_en),
        .addr1(bp_index),
        .re1(bp_active),
        .rd1(bp_counter)
    );

    assign bp_wr_index = (bp_init_active) ? (bp_init_index) : (bp_update_fifo_index);
    wire [1:0] bp_wr_data = (bp_init_active) ? (2'd1) : (bp_update_data);
    wire bp_wr_en = (bp_init_active) ? (1'b1) : (bp_update_en);

    reg bp_update_fifo_ready;
    wire bp_update_fifo_valid;
    wire [`BHT_ABITS-1:0] bp_update_fifo_index;
    wire bp_update_fifo_taken;
    wire bp_update_fifo_input_ready;
    fifo_nd #(.WIDTH(`BHT_ABITS+1), .ABITS(2)) bp_update_fifo (
        .clk(clk),
        .rst(rst),
        .a_data({bp_update_index, bp_update_taken}),
        .a_valid(bp_update),
        .a_ready(bp_update_fifo_input_ready),
        .a_almost_full(),
        .b_data({bp_update_fifo_index, bp_update_fifo_taken}),
        .b_valid(bp_update_fifo_valid),
        .b_ready(bp_update_fifo_ready)
    );

    // Happnes, but rare. Shouldn't affect performance much
    /*always @(posedge clk) begin
        if (!bp_update_fifo_input_ready && ip_if_branch) begin
            $display("BP update queue overflow");
        end
    end*/

    wire [1:0] bp_counter_inc = (bp_update_counter == 2'b11) ? 2'b11 : bp_update_counter + 1;
    wire [1:0] bp_counter_dec = (bp_update_counter == 2'b00) ? 2'b00 : bp_update_counter - 1;
    wire [1:0] bp_update_data = (bp_update_fifo_taken) ? bp_counter_inc : bp_counter_dec;
    wire bp_update_ren = !bp_update_fifo_ready && bp_update_fifo_valid; // R
    wire bp_update_en = bp_update_fifo_ready && bp_update_fifo_valid; // W
    always @(posedge clk) begin
        if (bp_update_fifo_ready)
            bp_update_fifo_ready <= 1'b0;
        else
            bp_update_fifo_ready <= bp_update_fifo_valid;
    end

endmodule