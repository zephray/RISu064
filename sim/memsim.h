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

class Memsim {
public:
    Memsim(uint64_t base, uint64_t size, bool verbose, int latency);
    void reset();
    void load_file(char *fn);
    void apply(uint64_t addr, uint64_t &rdata, uint64_t wdata, uint8_t wmask,
            uint8_t we, uint8_t valid, uint8_t &ready);
private:
    // Settings
    int latency;
    uint64_t base;
    uint64_t size;
    bool verbose;
    // Accepted memory request
    uint64_t req_addr;
    uint64_t req_wdata;
    uint8_t req_wmask;
    uint8_t req_we;
    int req_valid;
    // Other state
    int latency_counter;
    uint64_t *mem;
    uint64_t bytemask_to_bitmask(uint8_t mask);
};
