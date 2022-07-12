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
#include <assert.h>
#include "memsim.h"

Memsim::Memsim(uint64_t base, uint64_t size, bool verbose, int latency) {
    this->mem = (uint64_t *)malloc(size);
    this->base = base;
    this->size = size;
    this->verbose = verbose;
    this->latency = latency;
    this->latency_counter = 0;
    this->req_valid = 0;
    assert((base & 0x7) == 0);
    assert((size & 0x7) == 0);
}

void Memsim::load_file(char *fn) {
    FILE *fp;
    fp = fopen(fn, "rb+");
    if (!fp) {
        fprintf(stderr, "Error: unable to open file %s\n", fn);
        exit(1);
    }
    fseek(fp, 0, SEEK_END);
    size_t fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    size_t result = fread((void *)mem, fsize, 1, fp);
    assert(result == 1);
    fclose(fp);
}

void Memsim::reset() {
    if (verbose) {
        fprintf(stderr, "Memory simulator reset\n");
    }
    req_valid = 0;
}

uint64_t Memsim::bytemask_to_bitmask(uint8_t mask) {
    uint64_t result = 0;
    for (int i = 0; i < 8; i++) {
        if (mask & 0x01)
            result |= 0xff << (i * 8);
        mask >>= 1;
    }
    return result;
}

void Memsim::apply(uint64_t addr, uint64_t &rdata, uint64_t wdata,
        uint8_t wmask, uint8_t we, uint8_t valid, uint8_t &ready) {
    if (valid) {
        req_valid = 1;
        req_addr = addr;
        req_wdata = wdata;
        req_wmask = wmask;
        req_we = we;
        latency_counter = 0;
    }

    if (req_valid) {
        if (latency_counter == latency) {
            uint64_t raddr;
            if (req_addr < base)
                return;
            raddr = req_addr - base;

            if (raddr >= size)
                return;
            
            raddr >>= 3; // only do 64-bit access

            if (req_we) {
                if (verbose)
                    printf("Memory %08lx W %016lx M %02x\n", req_addr,
                            req_wdata, req_wmask);
                uint64_t bitmask = bytemask_to_bitmask(req_wmask);
                mem[raddr] &= ~bitmask;
                mem[raddr] |= req_wdata & bitmask;
            }
            else {
                rdata = mem[raddr];
                if (verbose)
                    printf("Memory %08lx R %016lx\n", req_addr, rdata);
            }
            req_valid = 0;
            ready = 1;
            latency_counter = 0;
        }
        else {
            latency_counter++;
        }
    }
    else {
        ready = 0;
    }
}