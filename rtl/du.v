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

// This is a fully combinational unit
module du(
    input wire [31:0] instr,
    // Decoder output specific for integer pipe
    output reg [2:0] op,
    output reg option,
    output reg truncate,
    // Decoder output specific for LS pipe
    output reg mem_sign,
    output reg [1:0] mem_width,
    // Decoder common output
    output reg [2:0] op_type,
    output reg [1:0] operand1,
    output reg [1:0] operand2,
    output reg [63:0] imm,
    output reg legal,
    output reg wb_en,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd
);

    // Extract bit-fields
    wire [6:0] funct7 = instr[31:25];
    assign rs2 = instr[24:20];
    assign rs1 = instr[19:15];
    wire [2:0] funct3 = instr[14:12];
    assign rd = instr[11:7];
    wire [6:0] opcode = instr[6:0];

    // Decode known instructions

    // TODO: fix sign ext
    wire [63:0] imm_i_type = {{52{instr[31]}}, instr[31:20]};
    wire [63:0] imm_s_type = {{52{instr[31]}}, instr[31:25], instr[11:7]};
    wire [63:0] imm_b_type = {{51{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [63:0] imm_u_type = {{32{instr[31]}}, instr[31:12], 12'b0};
    wire [63:0] imm_j_type = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        legal = 1'b0;
        op = 3'bx;
        option = 1'bx;
        truncate = 1'bx;
        mem_sign = 1'bx;
        mem_width = 2'bx;
        op_type = 3'bx;
        operand1 = 2'bx;
        operand2 = 2'bx;
        imm = 64'bx;
        wb_en = 1'bx;

        case (opcode)
        // RV-I
        // Int pipe instructions
        `OP_LUI: begin
            op_type = `OT_INT;
            op = `ALU_ADDSUB;
            option = `ALUOPT_ADD;
            imm = imm_u_type;
            operand1 = `D_OPR1_ZERO;
            operand2 = `D_OPR2_IMM;
            truncate = 1'b0;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        `OP_AUIPC: begin
            op_type = `OT_INT;
            op = `ALU_ADDSUB;
            option = `ALUOPT_ADD;
            imm = imm_u_type;
            operand1 = `D_OPR1_PC;
            operand2 = `D_OPR2_IMM;
            truncate = 1'b0;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        `OP_INTIMM: begin
            op_type = `OT_INT;
            op = funct3;
            if (funct3 == 3'b101)
                option = funct7[5];
            else
                option = 1'b0;
            option = 1'b0;
            imm = imm_i_type;
            operand1 = `D_OPR1_RS1;
            operand2 = `D_OPR2_IMM;
            truncate = 1'b0;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        `OP_INTREG: begin
            op_type = `OT_INT;
            op = funct3;
            option = funct7[5];
            operand1 = `D_OPR1_RS1;
            operand2 = `D_OPR2_RS2;
            truncate = 1'b0;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        `OP_INTIMMW: begin
            op_type = `OT_INT;
            op = funct3;
            if (funct3 == 3'b101)
                option = funct7[5];
            else
                option = 1'b0;
            imm = imm_i_type;
            operand1 = `D_OPR1_RS1;
            operand2 = `D_OPR2_IMM;
            truncate = 1'b1;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        `OP_INTREGW: begin
            op_type = `OT_INT;
            op = funct3;
            option = funct7[5];
            operand1 = `D_OPR1_RS1;
            operand2 = `D_OPR2_RS2;
            truncate = 1'b1;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        // LS pipe instructions
        `OP_LOAD: begin
            op_type = `OT_LOAD;
            mem_sign = funct3[2];
            mem_width = funct3[1:0];
            operand1 = `D_OPR1_RS1;
            operand2 = `D_OPR2_IMM;
            imm = imm_i_type;
            wb_en = 1'b1;
            legal = 1'b1;
        end
        `OP_STORE: begin
            op_type = `OT_STORE;
            mem_sign = funct3[2];
            mem_width = funct3[1:0];
            operand1 = `D_OPR1_RS1;
            operand2 = `D_OPR2_RS2;
            imm = imm_s_type;
            wb_en = 1'b0;
            legal = 1'b1;
        end
        // CSR pipe instructions

        endcase

        // RV-M

        // RV-A

        // RV-F

        // RV-D
    end

endmodule