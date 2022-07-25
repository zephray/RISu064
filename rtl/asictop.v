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

module asictop(
    input  wire         clk,
    input  wire         rst,
    output wire         ml_clk,
    output wire         ml_clkn,
    output wire         ml_abr,
    input  wire         ml_bbr,
    output wire [31:0]  ml_data_o,
    input  wire [31:0]  ml_data_i,
    output wire         ml_data_oe,
    output wire         ml_data_ie
);

    wire [31:0] bus_req_addr;
    wire        bus_req_wen;
    wire [63:0] bus_req_wdata;
    wire [7:0]  bus_req_wmask;
    wire [2:0]  bus_req_size;
    wire [4:0]  bus_req_srcid;
    wire        bus_req_valid;
    wire        bus_req_ready;
    wire [63:0] bus_resp_rdata;
    wire [2:0]  bus_resp_size;
    wire [4:0]  bus_resp_dstid;
    wire        bus_resp_valid;
    wire        bus_resp_ready;
    wire        ext_interrupt; // TODO: Do something about this

    // CPU core
    risu risu(
        .clk(clk),
        .rst(rst),
        .bus_req_addr(bus_req_addr),
        .bus_req_wen(bus_req_wen),
        .bus_req_wdata(bus_req_wdata),
        .bus_req_wmask(bus_req_wmask),
        .bus_req_size(bus_req_size),
        .bus_req_srcid(bus_req_srcid),
        .bus_req_valid(bus_req_valid),
        .bus_req_ready(bus_req_ready),
        .bus_resp_rdata(bus_resp_rdata),
        .bus_resp_size(bus_resp_size),
        .bus_resp_dstid(bus_resp_dstid),
        .bus_resp_valid(bus_resp_valid),
        .bus_resp_ready(bus_resp_ready),
        .ext_interrupt(ext_interrupt)
    );

    assign ext_interrupt = 1'b0;

    // External bus bridge
    kl2ml_bridge kl2ml_bridge(
        .clk(clk),
        .rst(rst),
        .kl_req_addr(bus_req_addr),
        .kl_req_wen(bus_req_wen),
        .kl_req_wdata(bus_req_wdata),
        .kl_req_wmask(bus_req_wmask),
        .kl_req_size(bus_req_size),
        .kl_req_srcid(bus_req_srcid),
        .kl_req_valid(bus_req_valid),
        .kl_req_ready(bus_req_ready),
        .kl_resp_rdata(bus_resp_rdata),
        /* verilator lint_off PINCONNECTEMPTY */
        .kl_resp_ren(),
        /* verilator lint_on PINCONNECTEMPTY */
        .kl_resp_size(bus_resp_size),
        .kl_resp_dstid(bus_resp_dstid),
        .kl_resp_valid(bus_resp_valid),
        .kl_resp_ready(bus_resp_ready),
        .ml_clk(ml_clk),
        .ml_clkn(ml_clkn),
        .ml_abr(ml_abr),
        .ml_bbr(ml_bbr),
        .ml_data_o(ml_data_o),
        .ml_data_i(ml_data_i),
        .ml_data_oe(ml_data_oe),
        .ml_data_ie(ml_data_ie)
    );

endmodule
