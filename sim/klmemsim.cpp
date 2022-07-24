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
// TODO: Allow pipelined access
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include "klmemsim.h"

KLMemsim::KLMemsim(uint64_t base, uint64_t size) {
    this->base = base;
    this->size = size;
    this->mem = (uint64_t *)malloc(size);
    assert(this->mem);
    cur_beatcount = 0;
}

KLMemsim::~KLMemsim() {
    free(mem);
}

void KLMemsim::set_verbose(bool verbose) {
    this->verbose = verbose;
}

void KLMemsim::reset() {
    // Called during simulator reset
    cur_beatcount = 0;
}

uint64_t KLMemsim::read(uint64_t addr) {
    // Unaligned access is legal
    addr -= base;
    addr >>= 3;
    return mem[addr];
}

void KLMemsim::write(uint64_t addr, uint64_t data, uint8_t mask) {
    addr -= base;
    addr >>= 3;
    if (mask == 0xff) {
        mem[addr] = data;
    }
    else {
        uint64_t d = mem[addr];
        uint64_t bm = get_bitmask(mask);
        d &= ~bm;
        d |= data & bm;
        mem[addr] = d;
    }
}

int KLMemsim::get_beats(uint8_t size) {
    int byte_size = (1l << size);
    int beats = (byte_size + 7) / 8;
    return beats;
}

uint64_t KLMemsim::get_bitmask(uint8_t mask) {
    uint64_t bm = 0;
    for (int i = 0; i < 8; i++) {
        if (mask & 0x01)
            bm |= (0xffull << i * 8);
        mask >>= 1;
    }
    return bm;
}

void KLMemsim::apply(uint32_t req_addr, uint8_t req_wen, uint64_t req_wdata,
            uint8_t req_wmask, uint8_t req_size, uint8_t req_srcid,
            uint8_t req_valid, uint8_t &req_ready, uint64_t &resp_rdata,
            uint8_t &resp_ren, uint8_t &resp_size, uint8_t &resp_dstid,
            uint8_t &resp_valid, uint8_t resp_ready) {
    // Called during every posedge clk
    // Default values
    resp_valid = 0;
    req_ready = 1;
    // Only handle new request if no active request
    if ((cur_beatcount == 0) && (req_valid)) {
        cur_addr = req_addr;
        cur_wen = req_wen;
        cur_id = req_srcid;
        cur_size = req_size;
        cur_beatcount = get_beats(req_size);
        cur_firstbeat = 1;
        cur_bubble = 0;
    }
    // Processing request
    if (cur_beatcount != 0) {
        if (cur_wen) {
            // Write request
            // This is a multi beat command
            req_ready = 1;
            if (cur_bubble) {
                if (resp_ready) { 
                    // Accepted
                    req_ready = 1;
                    cur_beatcount = 0;
                    if (verbose)
                        fprintf(stderr, "Accepted\n");
                }
                else {
                    // Not accepted last cycle, try again
                    resp_valid = 1;
                    req_ready = 0;
                }
            }
            else if (req_valid) {
                if (verbose)
                    fprintf(stderr,
                        "MEM: WR addr %08lx beat %d = %016lx mask %02x...\n",
                        cur_addr, cur_beatcount, req_wdata, req_wmask);
                // TODO: Handle corrupt
                write(cur_addr, req_wdata, req_wmask);
                cur_beatcount--;
                cur_addr += 8;
                if (cur_beatcount == 0) {
                    // Finished burst
                    resp_valid = 1;
                    resp_dstid = cur_id;
                    resp_size = cur_size;
                    resp_ren = 0;
                    resp_rdata = 0;
                    if (!resp_ready) {
                        // Ack not accepted, need to wait more cycles
                        cur_bubble = 1;
                        cur_beatcount = 1;
                        req_ready = 0;
                    }
                    else {
                        if (verbose)
                            fprintf(stderr, "Accepted\n");
                    }
                }
            }
        }
        else {
            // Read request
            if ((!resp_ready) && (!cur_firstbeat)) {
                // Previous beat is not processed
                if (verbose)
                    fprintf(stderr, "Stall\n");
                resp_valid = 1;
                req_ready = 0;
            }
            else {
                if (cur_firstbeat) {
                    cur_beatcount++;
                    cur_firstbeat = 0;
                }
                if (cur_beatcount == 1) {
                    // This is a single beat command
                    resp_valid = 0;
                    req_ready = 1;
                    cur_beatcount = 0;
                }
                else {
                    req_ready = 0;
                    resp_dstid = cur_id;
                    resp_size = cur_size;
                    resp_valid = 1;
                    resp_ren = 1;
                    resp_rdata = read(cur_addr);
                    if (verbose)
                        fprintf(stderr, "MEM: RD addr %08lx beat %d = %016lx...\n",
                            cur_addr, cur_beatcount - 2, resp_rdata);
                    cur_beatcount--;
                    cur_addr += 8;
                }
            } 
        }
    }
}

void KLMemsim::load_file(const char *fn) {
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
