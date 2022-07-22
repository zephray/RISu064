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
#pragma once

class KLMemsim {
public:
    KLMemsim(uint64_t base, uint64_t size);
    ~KLMemsim();
    void set_verbose(bool verbose);
    void reset();
    void apply(uint32_t req_addr, uint8_t req_wen, uint64_t req_wdata,
            uint8_t req_wmask, uint8_t req_size, uint8_t req_srcid,
            uint8_t req_valid, uint8_t &req_ready, uint64_t &resp_rdata,
            uint8_t &resp_size, uint8_t &resp_dstid, uint8_t &resp_valid,
            uint8_t resp_ready);
    void load_file(const char *fn);
private:
    // Configurations
    uint64_t base;
    uint64_t size;
    uint64_t *mem;
    bool verbose;
    // Current processing request
    int cur_beatcount;
    uint64_t cur_addr;
    uint8_t cur_wen;
    uint8_t cur_size;
    uint8_t cur_id;
    int cur_firstbeat;
    int cur_bubble;
    uint64_t get_bitmask(uint8_t mask);
    int get_beats(uint8_t size);
    uint64_t read(uint64_t addr);
    void write(uint64_t addr, uint64_t data, uint8_t mask);
};
