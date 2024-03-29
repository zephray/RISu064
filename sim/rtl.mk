################################################################################
## Filename: Makefile
## Engineer: Wenting Zhang
##
## Project: RISu64
## Description:
##   Makefile for building the RISu with Verilator. 
##   Use Xilinx ISE or Quartus for FPGA build.
################################################################################

TARGET ?= simtop
all: $(TARGET)

VOBJ := obj_dir
CXX   := g++
FBDIR := ../rtl/genrtl
CPUS ?= $(shell bash -c 'nproc --all')
VERBOSE ?= 0

.PHONY: all
$(TARGET): $(VOBJ)/V$(TARGET)__ALL.a

SUBMAKE := $(MAKE) --no-print-directory --directory=$(VOBJ) -f
ifeq ($(VERILATOR_ROOT),)
VERILATOR := verilator
else
VERILATOR := $(VERILATOR_ROOT)/bin/verilator
endif
VFLAGS := -Wall -Wno-fatal -MMD --trace -cc \
		-I../rtl/genrtl \
		-I../rtl/genrtl/basic \
		-I../rtl/genrtl/bus \
		-I../rtl/genrtl/core \
		-I../rtl/genrtl/system \
		-I../rtl/genrtl/third_party
ifeq ($(VERBOSE), 1)
VFLAGS += +define+VERBOSE=1
endif

$(VOBJ)/V$(TARGET)__ALL.a: $(VOBJ)/V$(TARGET).cpp $(VOBJ)/V$(TARGET).h
$(VOBJ)/V$(TARGET)__ALL.a: $(VOBJ)/V$(TARGET).mk

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
