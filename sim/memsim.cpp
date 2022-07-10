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
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "memsim.h"

MemsimContext *memsim_alloc(uint64_t base, uint64_t size, bool verbose,
        int latency) {
    MemsimContext *mem = (MemsimContext *)malloc(sizeof(MemsimContext) + size);
    mem->base = base;
    mem->size = size;
    mem->verbose = verbose;
    mem->latency = latency;
    return mem;
}

void memsim_reset(MemsimContext &ctx) {
    //
}

void memsim_apply(MemsimContext &ctx, uint64_t addr, uint64_t &rdata,
        uint64_t wdata, uint8_t we, uint8_t valid, uint8_t &ready) {
    if (valid) {
        if (ctx.latency_counter == ctx.latency) {
            uint64_t raddr;
            if (addr < ctx.base)
                return;
            raddr = addr - ctx.base;

            if (raddr >= ctx.size)
                return;
            
            raddr >>= 3; // only do 64-bit access

            if (we) {
                if (ctx.verbose)
                    printf("Memory %08lx W %016lx\n", addr, wdata);
                ctx.mem[raddr] = wdata;
            }
            else {
                rdata = ctx.mem[raddr];
                if (ctx.verbose)
                    printf("Memory %08lx R %016lx\n", addr, rdata);
            }
            ready = 1;
            ctx.latency_counter = 0;
        }
        else {
            ctx.latency_counter++;
        }
    }
    else {
        ready = 0;
    }
}