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


module risu(
    input wire clk,
    input wire rst,
    output wire [63:0] im_addr,
    input wire [63:0] im_rdata,
    output wire im_valid,
    input wire im_ready,
    output wire [63:0] dm_addr,
    input wire [63:0] dm_rdata,
    output wire [63:0] dm_wdata,
    output wire [7:0] dm_wmask,
    output wire dm_wen,
    output wire dm_valid,
    input wire dm_ready
);

    // Add CPU, cache, CLINT, etc. here.
    cpu cpu(
        .clk(clk),
        .rst(rst),
        .im_req_addr(im_addr),
        .im_req_valid(im_valid),
        .im_resp_rdata(im_rdata),
        .im_resp_valid(im_ready),
        .dm_req_addr(dm_addr),
        .dm_req_wdata(dm_wdata),
        .dm_req_wmask(dm_wmask),
        .dm_req_wen(dm_wen),
        .dm_req_valid(dm_valid),
        .dm_resp_rdata(dm_rdata),
        .dm_resp_valid(dm_ready)
    );

endmodule
