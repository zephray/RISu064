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
#include <time.h>

#include "verilated.h"
#include "verilated_vcd_c.h"
#ifdef TEST_SIMTOP
#include "Vsimtop.h"
#include "Vsimtop___024root.h"
#elif (defined(TEST_RISU))
#include "Vrisu.h"
#include "Vrisu___024root.h"
#endif

#include "memsim.h"
#include "klmemsim.h"
#include "earliercon.h"

#define CLK_PERIOD_PS 10000

#define RAM_BASE 0x80000000
#define RAM_SIZE 1*1024*1024

#define CON_BASE 0x20000000

// Verilator related
#ifdef TEST_SIMTOP
Vsimtop *core;
#elif (defined(TEST_RISU))
Vrisu *core;
#endif
VerilatedVcdC *trace;
uint64_t tickcount;

// Settings
bool enable_trace = false;
bool enable_stat = true;
bool unlimited = true;
bool verbose = false;
uint64_t max_cycles;

uint64_t stall_ipe;
uint64_t stall_lag;
uint64_t stall_lma;
uint64_t stall_md;
uint64_t if_nr_count;
uint64_t pc_override_count;
uint64_t branch_count;
uint64_t taken_count;
uint64_t mispredict_count;
uint64_t total_stall;

#ifdef TEST_SIMTOP
KLMemsim *ram;
#elif (defined(TEST_RISU))
Memsim *ram_iport;
Memsim *ram_dport;
#endif
Earliercon *earliercon;

#define CONCAT(a,b) a##b
#ifdef TEST_SIMTOP
#define SIGNAL(x) CONCAT(core->rootp->simtop__DOT__asictop__DOT__risu__DOT__cpu__DOT__,x)
#elif (defined(TEST_RISU))
#define SIGNAL(x) CONCAT(core->rootp->risu__DOT__cpu__DOT__,x)
#endif

double sc_time_stamp() {
    // This is in pS. Currently we use a 10ns (100MHz) clock signal.
    return (double)tickcount * (double)CLK_PERIOD_PS;
}

void tick() {
    // Software simulated parts should read the signal
    // before clock edge (simulate the combinational
    // path), but only put the data out after the
    // clock edge (DFF)

#ifdef TEST_SIMTOP
    // Note: accessing not mapped address causes deadlock
    uint8_t bus_req_ready = core->bus_req_ready;
    uint64_t bus_resp_rdata = core->bus_resp_rdata;
    uint8_t bus_resp_ren = core->bus_resp_ren;
    uint8_t bus_resp_size = core->bus_resp_size;
    uint8_t bus_resp_dstid = core->bus_resp_dstid;
    uint8_t bus_resp_valid = core->bus_resp_valid;

    ram->apply(
        core->bus_req_addr,
        core->bus_req_wen,
        core->bus_req_wdata,
        core->bus_req_wmask,
        core->bus_req_size,
        core->bus_req_srcid,
        core->bus_req_valid,
        bus_req_ready,
        bus_resp_rdata,
        bus_resp_ren,
        bus_resp_size,
        bus_resp_dstid,
        bus_resp_valid,
        core->bus_resp_ready
    );

    core->clk = 1;
    core->eval();

    core->bus_req_ready = bus_req_ready;
    core->bus_resp_rdata = bus_resp_rdata;
    core->bus_resp_ren = bus_resp_ren;
    core->bus_resp_size = bus_resp_size;
    core->bus_resp_dstid = bus_resp_dstid;
    core->bus_resp_valid = bus_resp_valid;
#elif (defined(TEST_RISU))
    uint64_t ib_resp_rdata = core->ib_resp_rdata;
    uint8_t ib_resp_valid = core->ib_resp_valid;
    uint64_t db_resp_rdata = core->db_resp_rdata;
    uint8_t db_resp_valid = core->db_resp_valid;

    ib_resp_valid = 0;
    ram_iport->apply(
        core->ib_req_addr,
        ib_resp_rdata,
        0,
        0,
        0,
        core->ib_req_valid,
        ib_resp_valid
    );

    db_resp_valid = 0;
    ram_dport->apply(
        core->db_req_addr,
        db_resp_rdata,
        core->db_req_wdata,
        core->db_req_wmask,
        core->db_req_wen,
        core->db_req_valid,
        db_resp_valid
    );
    earliercon->apply(
        core->db_req_addr,
        db_resp_rdata,
        core->db_req_wdata,
        core->db_req_wmask,
        core->db_req_wen,
        core->db_req_valid,
        db_resp_valid
    );

    core->clk = 1;
    core->eval();

    core->ib_resp_rdata = ib_resp_rdata;
    core->ib_resp_valid = ib_resp_valid;
    core->db_resp_rdata = db_resp_rdata;
    core->db_resp_valid = db_resp_valid;
#endif

    // Let combinational changes propagate
    core->eval();

    if (enable_stat) {
        /*if (SIGNAL(dec_ix_valid) == 1) {
            // Could issue, did it issue?
            if (SIGNAL(ix__DOT__dbg_stl_ipe)[0] || SIGNAL(ix__DOT__dbg_stl_ipe[1]))
                stall_ipe++;
            if (SIGNAL(ix__DOT__dbg_stl_lag)[0] || SIGNAL(ix__DOT__dbg_stl_lag[1]))
                stall_lag++;
            if (SIGNAL(ix__DOT__dbg_stl_lma)[0] || SIGNAL(ix__DOT__dbg_stl_lma[1]))
                stall_lma++;
            if (SIGNAL(ix__DOT__dbg_stl_mdi)[0] || SIGNAL(ix__DOT__dbg_stl_mdi[1]))
                stall_md++;
        }
        else {
            // Couldn't issue, why?
            if_nr_count++;
        }

        if (SIGNAL(dec_ix_ready) == 0) {
            total_stall++;
        }*/

        if (SIGNAL(ip_if_branch) && SIGNAL(ip0_wb_valid)) {
            branch_count++;
            if (SIGNAL(ip_if_branch_taken)) {
                taken_count++;
            }
        }

        if (SIGNAL(if_pc_override)) {
            pc_override_count++;
        }
    }

    if (enable_trace)
        trace->dump(tickcount * CLK_PERIOD_PS);
    core->clk = 0;
    
    core->eval();
    if (enable_trace)
        trace->dump(tickcount * CLK_PERIOD_PS + CLK_PERIOD_PS / 2);

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
#ifdef TEST_SIMTOP
    ram->reset();
#elif (defined(TEST_RISU))
    ram_dport->reset();
    ram_iport->reset();
    core->ib_req_ready = 1;
    core->db_req_ready = 1;
#endif
    // These are not reset by default as per RV priviledged mode spec
    // Reset them here for stat purposes
    SIGNAL(trap__DOT__minstret) = 0;
    SIGNAL(trap__DOT__mcycle) = 0;
    stall_ipe = 0;
    stall_lag = 0;
    stall_lma = 0;
    stall_md = 0;
    if_nr_count = 0;
    taken_count = 0;
    pc_override_count = 0;
    branch_count = 0;
    mispredict_count = 0;
    total_stall = 0;
}

int main(int argc, char *argv[]) {
    // Initialize testbench
    Verilated::commandArgs(argc, argv);

#ifdef TEST_SIMTOP
    core = new Vsimtop;
#elif (defined(TEST_RISU))
    core = new Vrisu;
#endif
    Verilated::traceEverOn(true);

#ifdef TEST_SIMTOP
    ram = new KLMemsim(RAM_BASE, RAM_SIZE);
#elif (defined(TEST_RISU))
    ram_dport = new Memsim(RAM_BASE, RAM_SIZE, false, 0);
    ram_iport = new Memsim(RAM_BASE, RAM_SIZE, false, 0);
#endif
    earliercon = new Earliercon(CON_BASE);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("RISu64 Simulator\n");
            printf("Available parameters:\n"); 
            printf("    --trace: Enable waveform trace\n"); 
            printf("    --ram <filename>: Preload RAM image file\n");
            printf("    --cycles <maxcycles>: Set simulation cycle limit\n");
        #if (defined(TEST_RISU))
            printf("    --ilat <cycles>: Instruction memory latency\n");
            printf("    --dlat <cycles>: Data memory latency\n");
        #endif
            printf("    --verbose: Enable verbose output\n");
            exit(0);
        }
        else if (strcmp(argv[i], "--trace") == 0) {
            enable_trace = true;
        }
        else if (strcmp(argv[i], "--ram") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no RAM filename provided\n");
                exit(1);
            }
            else {
            #ifdef TEST_SIMTOP
                ram->load_file(argv[i + 1]);
            #elif (defined(TEST_RISU))
                ram_dport->load_file(argv[i + 1]);
                ram_iport->copy(ram_dport);
            #endif
            }
        }
        else if (strcmp(argv[i], "--cycles") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no cycle limit number provided\n");
                exit(1);
            }
            else {
                unlimited = false;
                max_cycles = atoi(argv[i + 1]);
            }
        }
        #if (defined(TEST_RISU))
        else if (strcmp(argv[i], "--ilat") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no cycle number provided\n");
                exit(1);
            }
            else {
                ram_iport->set_latency(atoi(argv[i + 1]));
            }
        }
        else if (strcmp(argv[i], "--dlat") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no cycle number provided\n");
                exit(1);
            }
            else {
                ram_dport->set_latency(atoi(argv[i + 1]));
            }
        }
        #endif
        else if (strcmp(argv[i], "--verbose") == 0) {
        #ifdef TEST_SIMTOP
            ram->set_verbose(true);
        #elif (defined(TEST_RISU))
            ram_dport->set_verbose(true);
            ram_iport->set_verbose(true);
        #endif
            verbose = true;
        }
    }

    if (enable_trace) {
        trace = new VerilatedVcdC;
        core->trace(trace, 99);
        trace->open("trace.vcd");
    }

    // Start simulation
    if (verbose)
        printf("Simulation start.\n");

    clock_t time = clock();

    reset();

    bool running = true;
    while (running) {
        tick();
        
        if ((!unlimited) && (tickcount > max_cycles)) {
            break;
        }

        if (SIGNAL(ix_trap_int) && (SIGNAL(ix_trap_cause) == 3) && SIGNAL(ix_trap_valid)) {
            printf("Called ebreak, stopping\n");
            break;
        }

        /*if (!SIGNAL(dec_ix_legal) && SIGNAL(dec_ix_valid)) {
            if (verbose)
                printf("Encountered illegal instruction\n");
            break;
        }*/
    }

    time = clock() - time;
    time /= (CLOCKS_PER_SEC / 1000);
    if (time == 0) time = 1;

    if (enable_stat) {
        printf("Simulation stopped after %ld cycles,\n"
                "average simulation speed: %ld kHz.\n",
                tickcount, tickcount / time);
        for (int i = 0; i < 31; i++) {
            printf("R%d = %016lx\n", i + 1, SIGNAL(rf__DOT__rf_array[i]));
        }

        uint64_t instret = SIGNAL(trap__DOT__minstret);
        uint64_t cycle = SIGNAL(trap__DOT__mcycle);
        printf("Retired %lu instructions in %lu cycles. Average IPC: %.1f\n",
                instret, cycle, (float)instret / (float)cycle);
        
        uint64_t predicted = SIGNAL(ip0__DOT__ip_branch_support__DOT__dbg_bp_correct) +
                SIGNAL(ip1__DOT__ip_branch_support__DOT__dbg_bp_correct);;
        uint64_t btb_miss_on_predict = SIGNAL(ip0__DOT__ip_branch_support__DOT__dbg_btb_miss) +
                SIGNAL(ip1__DOT__ip_branch_support__DOT__dbg_btb_miss);

        /*printf("Total stall/ bubbles: %lu\n", cycle - instret);
        printf("Stall frontend stall: %lu\n", if_nr_count);
        printf("Total backend stall: %lu\n", total_stall);
        printf("Bubbles due to branching: %lu\n", mispredict_count * 2);
        printf("Stall due to insufficient IFQ: %lu\n", if_nr_count - mispredict_count * 2);
        printf("Stall due to integer EU busy (WB limited): %lu\n", stall_ipe);
        printf("Stall due to load store structural latency: %lu\n", stall_lag);
        printf("Stall due to load store memory latency: %lu\n", stall_lma);
        printf("Stall due to multiply/ divide unit busy: %lu\n", stall_md);
        printf("Stall due to WAW on integer EU: %lu\n", SIGNAL(ix__DOT__dbg_stl_ip0waw_cntr));
        printf("Stall due to WAW on load store: %lu\n", SIGNAL(ix__DOT__dbg_stl_lspwaw_cntr));
        printf("Stall due to WAW on multiply: %lu\n", SIGNAL(ix__DOT__dbg_stl_lspwaw_cntr));*/
        printf("Total frontend stall: %lu\n", SIGNAL(ix__DOT__dbg_cntr_fe_stall));
        printf("Frontend stall minus branching: %lu\n", SIGNAL(ix__DOT__dbg_cntr_fe_stall) - pc_override_count * 2);
        printf("Total cycles no issue at all: %lu\n", SIGNAL(ix__DOT__dbg_cntr_no_issue));
        printf("Total cycles issue 1 instruction: %lu\n", SIGNAL(ix__DOT__dbg_cntr_one_issue));
        printf("Total cycles issue 2 instructions: %lu\n", SIGNAL(ix__DOT__dbg_cntr_dual_issue));
        printf("Dual-issue dependency check fail: %lu\n", SIGNAL(ix__DOT__dbg_cntr_dep_fail));
        printf("Dual-issue RAW dependency: %lu\n", SIGNAL(ix__DOT__dbg_cntr_dep_raw));
        printf("Dual-issue WAW dependency: %lu\n", SIGNAL(ix__DOT__dbg_cntr_dep_waw));
        printf("Unsupported branch and load store issue: %lu\n", SIGNAL(ix__DOT__dbg_cntr_str_brls));
        printf("Unsupported branch and branch issue: %lu\n", SIGNAL(ix__DOT__dbg_cntr_str_brbr));
        printf("Unsupported branch and other issue: %lu\n", SIGNAL(ix__DOT__dbg_cntr_str_brother));

        printf("Stall due to branching: %lu\n", pc_override_count * 4);
        printf("Total branches: %lu\n", branch_count);
        if (branch_count != 0) {
            printf("Taken branches: %lu (%ld%%)\n", taken_count, taken_count * 100 / branch_count);
            printf("Branch predictor correct: %lu (%ld%%)\n", predicted, predicted * 100 / branch_count);
            printf("BTB miss on predicted branches: %lu (%ld%%)\n", btb_miss_on_predict, btb_miss_on_predict * 100 / predicted);
            printf("Combined mistaken branches: %lu (Correct %ld%%)\n", pc_override_count,
                    100 - pc_override_count * 100 / branch_count);
        }
    }

    int retval;
    if ((SIGNAL(rf__DOT__rf_array[9]) == 0) &&
            (SIGNAL(rf__DOT__rf_array[16]) == 93)) {
        printf("Test passed\n");
        retval = 0;
    }
    else {
        printf("Test failed\n");
        retval = 1;
    }

    if (enable_trace) {
        trace->close();
    }

#ifdef TEST_SIMTOP
    delete ram;
#elif (defined(TEST_RISU))
    delete ram_iport;
    delete ram_dport;
#endif

    delete earliercon;

    return retval;
}