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
`include "mlink.vh"

// KLink to MLink bus bridge
module kl2ml_bridge(
    input  wire         clk,
    input  wire         rst,
    // KLink B side
    input  wire [31:0]  kl_req_addr,
    input  wire         kl_req_wen,
    input  wire [63:0]  kl_req_wdata,
    input  wire [7:0]   kl_req_wmask,
    input  wire [2:0]   kl_req_size,
    input  wire [4:0]   kl_req_srcid,
    input  wire         kl_req_valid,
    output wire         kl_req_ready,
    output wire [63:0]  kl_resp_rdata,
    output wire         kl_resp_ren,
    output wire [2:0]   kl_resp_size,
    output wire [4:0]   kl_resp_dstid,
    output wire         kl_resp_valid,
    input  wire         kl_resp_ready,
    // MLink A side
    output wire         ml_clk,
    output wire         ml_clkn,
    output wire         ml_abr,
    input  wire         ml_bbr,
    output wire [31:0]  ml_data_o,
    input  wire [31:0]  ml_data_i,
    output wire         ml_data_oe,
    output wire         ml_data_ie
);

    reg clk_div;
    always @(posedge clk) begin
        if (rst)
            clk_div <= 1'b0;
        else
            clk_div <= ~clk_div;
    end

    assign ml_clk = clk_div;
    assign ml_clkn = ~clk_div;

    // TODO: Aligned access + wmask to mask-less conversion
    ml_xcvr #(.INITIAL_ROLE(0)) ml_xcvr (
        .clk(clk),
        .rst(rst),
        .kl_tx_addr(kl_req_addr),
        .kl_tx_den(kl_req_wen),
        .kl_tx_data(kl_req_wdata),
        .kl_tx_size(kl_req_size),
        .kl_tx_id(kl_req_srcid),
        .kl_tx_valid(kl_req_valid),
        .kl_tx_ready(kl_req_ready),
        /* verilator lint_off PINCONNECTEMPTY */
        .kl_rx_addr(),
        /* verilator lint_on PINCONNECTEMPTY */
        .kl_rx_data(kl_resp_rdata),
        .kl_rx_den(kl_resp_ren),
        .kl_rx_size(kl_resp_size),
        .kl_rx_id(kl_resp_dstid),
        .kl_rx_valid(kl_resp_valid),
        .kl_rx_ready(kl_resp_ready),
        .ml_txbr(ml_abr),
        .ml_rxbr(ml_bbr),
        .ml_data_o(ml_data_o),
        .ml_data_i(ml_data_i),
        .ml_data_oe(ml_data_oe),
        .ml_data_ie(ml_data_ie)
    );

endmodule
