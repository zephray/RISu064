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

// System options
//`define USE_L1_CACHE

// 2**BTB_ABITS == BTB_DEPTH
`define BTB_ABITS       5
`define BTB_DEPTH       32

// 2**BHT_ABITS == BHT_DEPTH
`define BHT_ABITS       12
`define BHT_DEPTH       4096
// BHT memory is 8-bit wide
`define BHT_MEM_ABITS   (`BHT_ABITS - 2)
`define BHT_MEM_DEPTH   (`BHT_DEPTH / 4)

// Branch predictor
//`define BPU_ALWAYS_NOT_TAKEN
//`define BPU_ALWAYS_TAKEN
//`define BPU_GLOBAL_BIMODAL
//`define BPU_GLOBAL_GSHARE
//`define BPU_GLOBAL_GSELECT
`define BPU_TOURNAMENT

`ifdef BPU_GLOBAL_BIMODAL
    `define BPU_GLOBAL
`elsif BPU_GLOBAL_GSELECT
    `define BPU_GLOBAL
    `define BPU_GHR_WIDTH   3
`elsif BPU_GLOBAL_GSHARE
    `define BPU_GLOBAL
    `define BPU_GHR_WIDTH   `BHT_ABITS
`elsif BPU_TOURNAMENT
    `define BPU_GLOBAL
    `define BPU_GHR_WIDTH   `BHT_ABITS
`endif

// 2**RAS_DEPTH_BITS == RAS_DEPTH
`define RAS_DEPTH       16
`define RAS_DEPTH_BITS  4

// Enable forwarding from MEM to IX, may reduce Fmax
`define ENABLE_MEM_FORWARING

//`define ENABLE_MMU

`define TLB_ABITS       2
`define TLB_ENTRIES     4
