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

// These directly correspond to funct3
`define BS_EQ       3'd0
`define BS_NE       3'd1
`define BS_LT       3'd4
`define BS_GE       3'd5
`define BS_LTU      3'd6
`define BS_GEU      3'd7

// 2bit field, 3rd bit controls sign ext
// Send to memory pipe
`define MW_BYTE     2'd0
`define MW_HALF     2'd1
`define MW_WORD     2'd2
`define MW_DOUBLE   2'd3

// ALU operation
// Send to integer pipe
`define ALU_ADDSUB  4'd0
`define ALU_SLL     4'd1
`define ALU_SLT     4'd2
`define ALU_SLTU    4'd3
`define ALU_XOR     4'd4
`define ALU_SR      4'd5
`define ALU_OR      4'd6
`define ALU_AND     4'd7
`define ALU_EQ      4'd8

`define ALUOPT_ADD  1'b0
`define ALUOPT_SUB  1'b1
`define ALUOPT_SRL  1'b0
`define ALUOPT_SRA  1'b1

// OPCODE definition
// RV-I / Zifenci / Zicsr
`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_JAL      7'b1101111
`define OP_JALR     7'b1100111
`define OP_BRANCH   7'b1100011
`define OP_LOAD     7'b0000011
`define OP_STORE    7'b0100011
`define OP_INTIMM   7'b0010011
`define OP_INTIMMW  7'b0011011
`define OP_INTREG   7'b0110011
`define OP_INTREGW  7'b0111011
`define OP_FENCE    7'b0001111
`define OP_ENVCSR   7'b1110011
// RV-M
`define OP_MULDIV   7'b0110011
`define OP_MULDIVW  7'b0111011
// RV-F / RV-D
`define OP_FLOAD    7'b0000111
`define OP_FSTORE   7'b0100111
`define OP_FMADD    7'b1000011
`define OP_FMSUB    7'b1000111
`define OP_FNMSUB   7'b1001011
`define OP_FNMADD   7'b1001111
`define OP_FPREG    7'b1010011
// RV-A
`define OP_ATOMIC   7'b0101111

// Operand source by decoder
`define D_OPR1_RS1      2'd0
`define D_OPR1_ZERO     2'd1
`define D_OPR1_PC       2'd2
`define D_OPR1_ZIMM     2'd3

`define D_OPR2_RS2      2'd0
`define D_OPR2_IMM      2'd1
`define D_OPR2_4        2'd2

// Operation type
// Different types maybe steered into same FU
`define OT_INT          3'd0
`define OT_BRANCH       3'd1
`define OT_LOAD         3'd2
`define OT_STORE        3'd3
`define OT_FENCE        3'd4
`define OT_MUL          3'd5
`define OT_CSR          3'd6
`define OT_FP           3'd7

// Destination availability
`define DA_MEM          2'd0 // available by the end of EX
`define DA_WB           2'd1 // available by the end of MEM

// Branch predictor result
`define BP_NOT_TAKEN    1'b0
`define BP_TAKEN        1'b1

// Branch instruction type
`define BT_NONE         2'd0
`define BT_JAL          2'd1
`define BT_JALR         2'd2
`define BT_BCOND        2'd3

// Branch conditions
`define BC_EQ           3'd0
`define BC_NE           3'd1
`define BC_LT           3'd2
`define BC_GE           3'd3
`define BC_LTU          3'd4
`define BC_GEU          3'd5

`define BB_PC           1'b0
`define BB_RS1          1'b1

// CSR operations
`define CSR_RW          2'd1
`define CSR_RS          2'd2
`define CSR_RC          2'd3


// Defines for bus link
`define WL_Get          1'd0
`define WL_Put          1'd1
`define WL_AccessAck    1'd0
`define WL_AccessDat    1'd1