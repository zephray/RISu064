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
    input  wire         clk,
    input  wire         rst,
    output wire [47:0]  bus_req_addr,
    output wire         bus_req_wen,
    output wire [63:0]  bus_req_wdata,
    output wire [7:0]   bus_req_wmask,
    output wire [2:0]   bus_req_size,
    output wire [4:0]   bus_req_srcid,
    output wire         bus_req_valid,
    input  wire         bus_req_ready,
    input  wire [63:0]  bus_resp_rdata,
    input  wire [2:0]   bus_resp_size,
    input  wire [4:0]   bus_resp_dstid,
    input  wire         bus_resp_valid,
    output wire         bus_resp_ready
);

    parameter USE_L1_CACHE = 1'b0;

    // Signals from CPU
    wire [47:0] im_req_addr;
    wire        im_req_valid;
    wire        im_req_ready;
    wire [63:0] im_resp_rdata;
    wire        im_resp_valid;
    wire        im_invalidate_req;
    wire        im_invalidate_resp;
    wire [47:0] dm_req_addr;
    wire [63:0] dm_req_wdata;
    wire [7:0]  dm_req_wmask;
    wire        dm_req_wen;
    wire        dm_req_valid;
    wire        dm_req_ready;
    wire [63:0] dm_resp_rdata;
    wire        dm_resp_valid;

    /* verilator lint_off UNUSED */
    // Only use low 48 bit of address
    wire [63:0] cpu_im_req_addr;
    wire [63:0] cpu_dm_req_addr;
    assign im_req_addr = cpu_im_req_addr[47:0];
    assign dm_req_addr = cpu_dm_req_addr[47:0];
    /* verilator lint_on UNUSED */

    // Add CPU, cache, CLINT, etc. here.
    cpu cpu(
        .clk(clk),
        .rst(rst),
        .im_req_addr(cpu_im_req_addr),
        .im_req_valid(im_req_valid),
        .im_req_ready(im_req_ready),
        .im_resp_rdata(im_resp_rdata),
        .im_resp_valid(im_resp_valid),
        .im_invalidate_req(im_invalidate_req),
        .im_invalidate_resp(im_invalidate_resp),
        .dm_req_addr(cpu_dm_req_addr),
        .dm_req_wdata(dm_req_wdata),
        .dm_req_wmask(dm_req_wmask),
        .dm_req_wen(dm_req_wen),
        .dm_req_valid(dm_req_valid),
        .dm_req_ready(dm_req_ready),
        .dm_resp_rdata(dm_resp_rdata),
        .dm_resp_valid(dm_resp_valid)
    );

    // Signals after cache, or directly from CPU
    wire [47:0] ib_req_addr;
    wire [2:0]  ib_req_size;
    wire        ib_req_valid;
    wire        ib_req_ready;
    wire [63:0] ib_resp_rdata;
    wire        ib_resp_valid;
    wire [47:0] db_req_addr;
    wire [63:0] db_req_wdata;
    wire [7:0]  db_req_wmask;
    wire        db_req_wen;
    wire [2:0]  db_req_size;
    wire        db_req_valid;
    wire        db_req_ready;
    wire [63:0] db_resp_rdata;
    wire        db_resp_valid;

    generate
    if (USE_L1_CACHE) begin: l1_cache
        
    end
    else begin: no_cache
        assign ib_req_addr = im_req_addr;
        assign ib_req_size = 3'd3; // Fixed 64-bit transfer
        assign ib_req_valid = im_req_valid;
        assign im_req_ready = ib_req_ready;
        assign im_resp_rdata = ib_resp_rdata;
        assign im_resp_valid = ib_resp_valid;
        assign db_req_addr = dm_req_addr;
        assign db_req_wdata = dm_req_wdata;
        assign db_req_wmask = dm_req_wmask;
        assign db_req_wen = dm_req_wen;
        assign db_req_size = 3'd3;
        assign db_req_valid = dm_req_valid;
        assign dm_req_ready = db_req_ready;
        assign dm_resp_rdata = db_resp_rdata;
        assign dm_resp_valid = db_resp_valid;
        // Tie-off invalidate request: there is no icache to begin with
        assign im_invalidate_resp = im_invalidate_req;
    end
    endgenerate

    kl_arbiter_2by1 kl_arbiter_2by1(
        .clk(clk),
        .rst(rst),
        // Instruction bus
        .up0_req_addr(ib_req_addr),
        .up0_req_wen(1'b0),
        .up0_req_wdata(64'bx),
        .up0_req_wmask(8'bx),
        .up0_req_size(ib_req_size),
        .up0_req_valid(ib_req_valid),
        .up0_req_ready(ib_req_ready),
        .up0_resp_rdata(ib_resp_rdata),
        .up0_resp_valid(ib_resp_valid),
        .up0_resp_ready(1'b1),
        // Data bus
        .up1_req_addr(db_req_addr),
        .up1_req_wen(db_req_wen),
        .up1_req_wdata(db_req_wdata),
        .up1_req_wmask(db_req_wmask),
        .up1_req_size(db_req_size),
        .up1_req_valid(db_req_valid),
        .up1_req_ready(db_req_ready),
        .up1_resp_rdata(db_resp_rdata),
        .up1_resp_valid(db_resp_valid),
        .up1_resp_ready(1'b1),
        // External port
        .dn_req_addr(bus_req_addr),
        .dn_req_wen(bus_req_wen),
        .dn_req_wdata(bus_req_wdata),
        .dn_req_wmask(bus_req_wmask),
        .dn_req_size(bus_req_size),
        .dn_req_srcid(bus_req_srcid),
        .dn_req_valid(bus_req_valid),
        .dn_req_ready(bus_req_ready),
        .dn_resp_rdata(bus_resp_rdata),
        .dn_resp_size(bus_resp_size),
        .dn_resp_dstid(bus_resp_dstid),
        .dn_resp_valid(bus_resp_valid),
        .dn_resp_ready(bus_resp_ready)
    );

endmodule
