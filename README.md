# RISu64

![pipeline_diagram](doc/pipeline.svg)

RISu64 (Reduced Instruction Set μProcessor 64 / Squirrel 64) is my toy 64-bit RISC-V compatible processor.

## Features

- RV64IMZicsr_Zifencei
- 7-stage pipeline: PCGen(F1), IMem(F2), Decode(ID), Issue(IX), Execute(EX), DMem(MEM), Writeback(WB).
- In-order issue and out-of-order writeback
- Single issue for now
- BTB + Bimodal/Gselect/Gshare/Tournament + RAS branch predictors
- 1x Integer (arithmetic, barrel shifter, branch)
- 1x Load store unit (aligned access only, unaligned access generate precise exception)
- 1x Multiply/ divide unit (non-pipelined, 3/6-cycle 32/64bit multiply, 34/66-cycle 64bit divide)
- Optional L1 instruction and data cache (2-way set associative blocking cache)
- Machine mode only with exception and interrupt support
- Written in portable synthesizable Verilog

## Performance

The performance varies based on configurations:

- 7-stage + 512-entry Bimodal + 32-entry BTB + TCM: **2.93 Coremark/MHz**
- 7-stage + 4K-entry Tournament + 32-entry BTB + TCM: **2.97 Coremark/MHz**
- 7-stage + 4K-entry Tournament + 32-entry BTB + 16KB I/D cache: **2.94 Coremark/MHz**
- 7-stage + 16K-entry Tournament + 1K-entry BTB + TCM: **3.08 Coremark/MHz**

The core currently only track up to 2 in-flight load/ store without stalling the core, due to the lack of a proper load-store queue and the lack of a scalable dependency check mechanism. This may change in the future.

## Status

This project is still under active development, things may break at anytime (or already broken). The features listed above are already in place and at least working to some degree.

Here is just a random list of things I want to / is working on that may or may not coming to this core:

- Compressed instruction support
- FPU support
- Dual-issue
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
