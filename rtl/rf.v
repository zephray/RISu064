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

module rf(
    input  wire         clk,
    input  wire         rst,
    input  wire [4:0]   rf_rsrc [0:RD_PORTS-1],
    output wire [63:0]  rf_rdata [0:RD_PORTS-1],
    input  wire         rf_wen [0:WR_PORTS-1],
    input  wire [4:0]   rf_wdst [0:WR_PORTS-1],
    input  wire [63:0]  rf_wdata [0:WR_PORTS-1]
);
    parameter RD_PORTS = 2;
    parameter WR_PORTS = 1;

    reg [63:0] rf_array [31:1];

    genvar i;
    generate
    for (i = 0; i < WR_PORTS; i = i + 1) begin
        always @(posedge clk) begin
            if (rf_wen[i]) begin
                rf_array[rf_wdst[i]] <= rf_wdata[i];
            end
        end
    end

    for (i = 0; i < RD_PORTS; i = i + 1) begin
        assign rf_rdata[i] = rf_array[rf_rsrc[i]];
    end
    endgenerate

endmodule
