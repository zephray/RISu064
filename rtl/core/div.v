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
// This is based on lowRISC's muntjac divider design.
`include "defines.vh"

module div(
    input  wire         clk,
    input  wire         rst,
    input  wire [63:0]  operand1,
    input  wire [63:0]  operand2,
    input  wire [2:0]   div_op,
    input  wire         req_valid,
    output wire         req_ready,
    output reg          resp_valid,
    output reg  [63:0]  resp_result
);

    // Comb signals of pre-processed inputs
    wire a_sign;
    wire b_sign;
    wire [63:0] a_mag;
    wire [63:0] b_mag;
    wire [63:0] a_rev;

    wire op_unsigned = div_op[0];
    wire op_rem = div_op[1];
    reg op_rem_reg;
    wire op_word = div_op[2];
    reg op_word_reg;

    wire a_signbit = (op_word) ? operand1[31] : operand1[63];
    wire b_signbit = (op_word) ? operand2[31] : operand2[63];
    assign a_sign = (op_unsigned) ? 1'b0 : a_signbit;
    assign b_sign = (op_unsigned) ? 1'b0 : b_signbit;
    wire [63:0] a_ext = (op_word) ? {{32{a_sign}}, operand1[31:0]} : operand1;
    wire [63:0] b_ext = (op_word) ? {{32{b_sign}}, operand2[31:0]} : operand2;
    assign a_mag = (a_sign) ? (-a_ext) : (a_ext);
    assign b_mag = (b_sign) ? (-b_ext) : (b_ext);

    wire [31:0] a_rev_32;
    wire [63:0] a_rev_64; 
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1)
            assign a_rev_32[i] = a_mag[31-i];
        for (i = 0; i < 64; i = i + 1)
            assign a_rev_64[i] = a_mag[63-i];
    endgenerate
    assign a_rev = (op_word) ? {32'b0, a_rev_32} : a_rev_64;

    localparam ST_IDLE = 2'd0;
    localparam ST_CALCULATE = 2'd1;
    localparam ST_OUTPUT = 2'd2;
    reg [1:0] state;
    reg [5:0] loop;
    reg [63:0] a, b;
    reg [63:0] quo, rem;
    reg quo_neg, rem_neg;

    wire [63:0] rem_shift = {rem[62:0], a[0]};
    wire [63:0] result_64 = (op_rem_reg) ?
            ((rem_neg) ? (-rem) : (rem)) :
            ((quo_neg) ? (-quo) : (quo));

    assign req_ready = state == ST_IDLE;

    always @(posedge clk) begin
        case (state)
        ST_IDLE: begin
            resp_valid <= 1'b0;
            if (req_valid) begin
                state <= ST_CALCULATE;
                loop <= op_word ? 31 : 63;
                quo <= 64'd0;
                rem <= 64'd0;
                a <= a_rev;
                b <= b_mag;
                quo_neg <= (a_sign ^ b_sign) && (b_mag != 0);
                rem_neg <= a_sign; 
                op_word_reg <= op_word;
                op_rem_reg <= op_rem;
            end
        end
        ST_CALCULATE: begin
            a <= {1'b0, a[63:1]};
            if (rem_shift >= b) begin
                rem <= rem_shift - b;
                quo <= {quo[62:0], 1'b1};
            end
            else begin
                rem <= rem_shift;
                quo <= {quo[62:0], 1'b0};
            end
            loop <= loop - 1;
            if (loop == 0) begin
                state <= ST_OUTPUT;
            end
        end
        ST_OUTPUT: begin
            state <= ST_IDLE;
            resp_valid <= 1'b1;
            resp_result <= (op_word_reg) ?
                    {{32{result_64[31]}}, result_64[31:0]} : result_64;
        end
        endcase

        if (rst) begin
            resp_valid <= 1'b0;
            state <= ST_IDLE;
        end
    end

endmodule
