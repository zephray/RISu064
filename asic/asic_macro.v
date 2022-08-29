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
module asic_macro (
    inout wire vccd1,
    inout wire vssd1,
    input wire clk,
    input wire rst,
    output wire clko,
    input wire [26:0] io_in,
    output wire [26:0] io_out,
    output wire [26:0] io_oeb
);
    wire ml_clk;
    wire ml_clkn;
    wire ml_abr;
    wire ml_bbr;
    wire [21:0] ml_data_o;
    wire [21:0] ml_data_i;
    wire ml_data_oe;
    wire ml_data_ie;
    wire extint_software;
    wire extint_timer;
    wire extint_external;

    asictop asictop (
        .clk(clk),
        .rst(rst),
        .ml_clk(ml_clk),
        .ml_clkn(ml_clkn),
        .ml_abr(ml_abr),
        .ml_bbr(ml_bbr),
        .ml_data_o(ml_data_o),
        .ml_data_i(ml_data_i),
        .ml_data_oe(ml_data_oe),
        .ml_data_ie(ml_data_ie),
        .extint_software(extint_software),
        .extint_timer(extint_timer),
        .extint_external(extint_external)
    );

    assign clko = ml_clk;
    assign io_out[21:0] = ml_data_o;
    assign io_oeb[21:0] = {22{!ml_data_oe}};
    assign ml_data_i = io_in[21:0];
    assign io_out[22] = ml_abr;
    assign io_oeb[22] = 1'b0;
    assign io_out[23] = 1'b0;
    assign ml_bbr = io_in[23];
    assign io_oeb[23] = 1'b1;
    assign io_out[26:24] = 3'd0;
    assign extint_software = io_in[24];
    assign extint_timer = io_in[25];
    assign extint_external = io_in[26];
    assign io_oeb[26:24] = 3'b111;
    
endmodule
