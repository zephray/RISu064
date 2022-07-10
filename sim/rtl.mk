################################################################################
## Filename: Makefile
## Engineer: Wenting Zhang
##
## Project: RISu64
## Description:
##   Makefile for building the RISu with Verilator. 
##   Use Xilinx ISE or Quartus for FPGA build.
################################################################################

all: risu

VOBJ := obj_dir
CXX   := g++
FBDIR := ../rtl
CPUS ?= $(shell bash -c 'nproc --all')

.PHONY: all
risu: $(VOBJ)/Vrisu__ALL.a

SUBMAKE := $(MAKE) --no-print-directory --directory=$(VOBJ) -f
ifeq ($(VERILATOR_ROOT),)
VERILATOR := verilator
else
VERILATOR := $(VERILATOR_ROOT)/bin/verilator
endif
VFLAGS := -Wall -Wno-fatal -MMD --trace -cc -I../rtl -I../rtl/third_party/fifo

$(VOBJ)/Vrisu__ALL.a: $(VOBJ)/Vrisu.cpp $(VOBJ)/Vrisu.h
$(VOBJ)/Vrisu__ALL.a: $(VOBJ)/Vrisu.mk

$(VOBJ)/V%.cpp $(VOBJ)/V%.h $(VOBJ)/V%.mk: $(FBDIR)/%.v
	$(VERILATOR) $(VFLAGS) $*.v

$(VOBJ)/V%.cpp: $(VOBJ)/V%.h
$(VOBJ)/V%.mk:  $(VOBJ)/V%.h
$(VOBJ)/V%.h: $(FBDIR)/%.v

$(VOBJ)/V%__ALL.a: $(VOBJ)/V%.mk
	$(SUBMAKE) V$*.mk -j$(CPUS)

.PHONY: clean
clean:
	rm -rf $(VOBJ)/*.mk
	rm -rf $(VOBJ)/*.cpp
	rm -rf $(VOBJ)/*.h
	rm -rf $(VOBJ)/
