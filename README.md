# RISu64

![pipeline_diagram](doc/pipeline.svg)

RISu64 (Reduced Instruction Set μProcessor 64 / Squirrel 64) is my toy 64-bit RISC-V compatible processor.

## Features

- RV64IMZicsr_Zifencei
- 7-stage pipeline: PCGen(F1), IMem(F2), Decode(ID), Issue(IX), Execute(EX), DMem(MEM), Writeback(WB).
- In-order issue and out-of-order writeback
- Dual-issue
- BTB + Bimodal/Gselect/Gshare/Tournament + RAS branch predictors
- 2x Integer (arithmetic, barrel shifter, branch)
- 1x Load store unit (aligned access only, unaligned access generate precise exception)
- 1x Multiply/ divide unit (non-pipelined, 3/6-cycle 32/64bit multiply, 34/66-cycle 64bit divide)
- Optional L1 instruction and data cache (2-way set associative blocking cache)
- Machine mode only with exception and interrupt support
- Written in portable synthesizable Verilog

## Performance

The performance varies based on configurations:

- Single-issue + 512-entry Bimodal + 32-entry BTB + TCM: 3.01 Coremark/MHz
- Single-issue + 4K-entry Tournament + 32-entry BTB + TCM: 3.06 Coremark/MHz
- Single-issue + 4K-entry Tournament + 32-entry BTB + 16KB L1$: 3.01 Coremark/MHz
- Dual-issue + 4K-entry Tournament + 32-entry BTB + TCM: 4.31 Coremark/MHz

Note:

1. Compiled with GCC 9.2.0, with the following options: ```-MD -O3 -mabi=lp64 -march=rv64im -mcmodel=medany -ffreestanding -nostdlib -fomit-frame-pointer -funroll-all-loops -finline-limit=1000 -ftree-dominator-opts -fno-if-conversion2 -fselective-scheduling -fno-code-hoisting -freorder-blocks-and-partition```
2. Single-issue is no longer supported in the latest branch, testing was carried out using commit ```efd0d3```
3. L1-cache is organized as 2-way set associative, 16KB each, with simulated unlimited L2 memory and 15-cycle latency
4. Each BPU entry is 2-bit, internally it expects 8-bit wide memory interface. 4K-entry = 1K x 8bit SRAM

## Status

This project is still under active development, things may break at anytime (or already broken). The features listed above are already in place and at least working to some degree.

Here is just a random list of things I want to / is working on that may or may not coming to this core:

- Compressed instruction support
- FPU support
- FGMT/ SMT
- Non-blocking L2 cache
- SMP and cache-coherency
- Maybe MMU
- Rewrite in BSV

## Acknowledgements

During the design of this processor, I have used the following projects as reference:

- [lowRISC's muntjac](https://github.com/lowRISC/muntjac), Apache 2.0 license
- [UltraEmbedded's biriscv](https://github.com/ultraembedded/biriscv), Apache 2.0 license

The following third-party code have been used:

- [Gary Guo's round robin arbiter](https://garyguo.net/), BSD license

## License

MIT
