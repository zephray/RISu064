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

// MLink to KLink bus bridge
module ml2kl_bridge(
    input  wire         clk,
    input  wire         rst,
    // KLink A side
    output reg  [31:0]  kl_req_addr,
    output wire         kl_req_wen,
    output wire [63:0]  kl_req_wdata,
    output reg  [7:0]   kl_req_wmask,
    output reg  [2:0]   kl_req_size,
    output wire [4:0]   kl_req_srcid,
    output wire         kl_req_valid,
    input  wire         kl_req_ready,
    input  wire [63:0]  kl_resp_rdata,
    input  wire         kl_resp_ren,
    input  wire [2:0]   kl_resp_size,
    input  wire [4:0]   kl_resp_dstid,
    input  wire         kl_resp_valid,
    output wire         kl_resp_ready,
    // MLink B side
    input  wire         ml_abr,
    output wire         ml_bbr,
    output wire [31:0]  ml_data_o,
    input  wire [31:0]  ml_data_i,
    output wire         ml_data_oe,
    output wire         ml_data_ie,
    // Sideband signal
    input  wire [31:0]  sideband
);

    // Mask-less to aligned access + wmask conversion
    wire [2:0] ml_req_size;
    wire [31:0] ml_req_addr;
    integer i;
    always @(*) begin
        kl_req_size = (ml_req_size < 3'd3) ? 3'd3 : ml_req_size;
        kl_req_addr = {ml_req_addr[31:3], 3'b0};
        kl_req_wmask = 8'hff;
        if (ml_req_size == 0) begin
            // Byte access
            for (i = 0; i < 8; i = i + 1) begin
                if (ml_req_addr[2:0] == i[2:0])
                    kl_req_wmask = (8'd1 << i);
            end
        end
        else if (ml_req_size == 1) begin
            // Half access
            for (i = 0; i < 8; i = i + 2) begin
                if (ml_req_addr[2:0] == i[2:0])
                    kl_req_wmask = (8'd3 << i);
            end
        end
        else if (ml_req_size == 2) begin
            // Word access
            for (i = 0; i < 8; i = i + 4) begin
                if (ml_req_addr[2:0] == i[2:0])
                    kl_req_wmask = (8'd15 << i);
            end
        end
    end

    wire [31:0] kl_tx_addr;
    wire kl_tx_den;
    wire [63:0] kl_tx_data;
    wire [2:0] kl_tx_size;
    wire [4:0] kl_tx_id;
    wire kl_tx_valid;
    wire kl_tx_ready;

    wire [31:0] kl_sbtx_addr = sideband;
    wire kl_sbtx_den = 1'b0;
    wire [63:0] kl_sbtx_data = 64'bx;
    wire [2:0] kl_sbtx_size = 3'd0;
    wire [4:0] kl_sbtx_id = 5'd31;
    reg kl_sbtx_valid;
    wire kl_sbtx_ready;

    reg [31:0] sideband_last;
    always @(posedge clk) begin
        sideband_last <= sideband;
        if (kl_sbtx_valid && kl_sbtx_ready) begin
            kl_sbtx_valid <= 1'b0;
        end
        else if ((sideband_last != sideband) && (!kl_resp_valid)) begin
            kl_sbtx_valid <= 1'b1;
        end
        if (rst)
            kl_sbtx_valid <= 1'b0;
    end

    assign kl_tx_addr = (kl_sbtx_valid) ? (kl_sbtx_addr) : (32'd0);
    assign kl_tx_den = (kl_sbtx_valid) ? (kl_sbtx_den) : (kl_resp_ren);
    assign kl_tx_data = (kl_sbtx_valid) ? (kl_sbtx_data) : (kl_resp_rdata);
    assign kl_tx_size = (kl_sbtx_valid) ? (kl_sbtx_size) : (kl_resp_size);
    assign kl_tx_id = (kl_sbtx_valid) ? (kl_sbtx_id) : (kl_resp_dstid);
    assign kl_tx_valid = (kl_sbtx_valid) ? (kl_sbtx_valid) : (kl_resp_valid);
    assign kl_resp_ready = (kl_sbtx_valid) ? (1'b0) : (kl_tx_ready);
    assign kl_sbtx_ready = (kl_sbtx_valid) ? (kl_tx_ready) : (1'b0);
    
    ml_xcvr #(.INITIAL_ROLE(1)) ml_xcvr (
        .clk(clk),
        .rst(rst),
        .kl_tx_addr(kl_tx_addr),
        .kl_tx_den(kl_tx_den),
        .kl_tx_data(kl_tx_data),
        .kl_tx_size(kl_tx_size),
        .kl_tx_id(kl_tx_id),
        .kl_tx_valid(kl_tx_valid),
        .kl_tx_ready(kl_tx_ready),
        .kl_rx_addr(ml_req_addr),
        .kl_rx_data(kl_req_wdata),
        .kl_rx_den(kl_req_wen),
        .kl_rx_size(ml_req_size),
        .kl_rx_id(kl_req_srcid),
        .kl_rx_valid(kl_req_valid),
        .kl_rx_ready(kl_req_ready),
        .ml_txbr(ml_bbr),
        .ml_rxbr(ml_abr),
        .ml_data_o(ml_data_o),
        .ml_data_i(ml_data_i),
        .ml_data_oe(ml_data_oe),
        .ml_data_ie(ml_data_ie)
    );

endmodule
