//
// RISu64 simulator
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
#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vrisu.h"
#include "Vrisu___024root.h"

#include "memsim.h"

#define RAM_SIZE 4096
#define ROM_SIZE 4096
#define RAM_BASE 0x80000000
#define ROM_BASE 0x10000000

// Verilator related
Vrisu *core;
VerilatedVcdC *trace;
uint64_t tickcount;

// Settings
bool quiet = false;
bool enable_trace = false;
bool enable_itrace = false;
bool unlimited = false;
uint64_t max_cycles = 30;

MemsimContext *ram;
MemsimContext *rom;

void tick() {
    // Software simulated parts should read the signal
    // before clock edge (simulate the combinational
    // path), but only put the data out after the
    // clock edge (DFF)

    // Note: accessing not mapped address causes deadlock
    uint64_t im_rdata;
    uint8_t im_ready;
    uint64_t dm_rdata;
    uint8_t dm_ready;
    memsim_apply(*rom,
        core->im_addr,
        im_rdata,
        0,
        0,
        core->im_valid,
        im_ready
    );
    memsim_apply(*ram,
        core->dm_addr,
        dm_rdata,
        core->dm_wdata,
        core->dm_wen,
        core->dm_valid,
        dm_ready
    );

    core->clk = 1;
    core->eval();

    core->im_rdata = im_rdata;
    core->im_ready = im_ready;
    core->dm_rdata = dm_rdata;
    core->dm_ready = dm_ready;

    // Let combinational changes propergate
    core->eval();

    if (enable_trace)
        trace->dump(tickcount * 10000);
    core->clk = 0;
    
    core->eval();
    if (enable_trace)
        trace->dump(tickcount * 10000 + 5000);

    if (enable_itrace) {
        /*if (core->rootp->risu__DOT__cpu__DOT__mem_wb_valid) {
            printf("Cycle %08ld PC %08lx WB REG[%02d] <- %016lx\n",
                    tickcount,
                    core->rootp->risu__DOT__cpu__DOT__mem_wb_pc,
                    core->rootp->risu__DOT__cpu__DOT__mem_wb_dst,
                    core->rootp->risu__DOT__cpu__DOT__mem_wb_result);
        }*/
    }

    tickcount++;
}

void reset() {
    core->rst = 0;
    tick();
    core->rst = 1;
    tick();
    tick();
    tick();
    core->rst = 0;
    memsim_reset(*ram);
    memsim_reset(*rom);
}

void load_file(uint8_t *dst, char *fn) {
    FILE *fp;
    fp = fopen(fn, "rb+");
    if (!fp) {
        fprintf(stderr, "Error: unable to open file %s\n", fn);
        exit(1);
    }
    fseek(fp, 0, SEEK_END);
    size_t fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    size_t result = fread(dst, fsize, 1, fp);
    assert(result == 1);
    fclose(fp);
}

int main(int argc, char *argv[]) {
    // Initialize testbench
    Verilated::commandArgs(argc, argv);

    core = new Vrisu;
    Verilated::traceEverOn(true);

    rom = memsim_alloc(ROM_BASE, ROM_SIZE, true, 0);
    ram = memsim_alloc(RAM_BASE, RAM_SIZE, true, 2);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--trace") == 0) {
            enable_trace = true;
        }
        else if (strcmp(argv[i], "--itrace") == 0) {
            enable_itrace = true;
        }
        else if (strcmp(argv[i], "--rom") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no ROM filename provided\n");
                exit(1);
            }
            else {
                load_file((uint8_t *)rom->mem, argv[i + 1]);
            }
        }
    }

    if (enable_trace) {
        trace = new VerilatedVcdC;
        core->trace(trace, 99);
        trace->open("trace.vcd");
    }

    // Start simulation
    if (!quiet)
        printf("Simulation start.\n");

    reset();

    bool running = true;
    while (running) {
        tick();
        
        if ((!unlimited) && (tickcount > max_cycles)) {
            break;
        }
    }

    if (!quiet) {
        printf("Stop.\n");
        for (int i = 0; i < 31; i++) {
            printf("R%d = %016lx\n", i + 1, core->rootp->risu__DOT__cpu__DOT__ix__DOT__rf[i]);
        }
    }
       

    if (enable_trace) {
        trace->close();
    }

    return 0;
}