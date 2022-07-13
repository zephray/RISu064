TARGET := simulator
OBJODIR := obj
RTLDIR := .

ifeq ($(VERILATOR_ROOT),)
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
endif
VROOT := $(VERILATOR_ROOT)
VINCD := $(VROOT)/include
RTLOBJDIR := $(RTLDIR)/obj_dir
RTLOBJ := $(RTLOBJDIR)/Vrisu__ALL.a

CC = g++
CXX = g++
LD = g++

LIBS := -lm

COMMONFLAGS := \
	-Wall -Og -g

CPPFLAGS := \
	-faligned-new \
	-std=c++17

LDFLAGS :=

INCLUDES += \
	-I. \
	-I$(RTLOBJDIR) \
	-I$(RTLDIR) \
	-I$(VINCD) \
	-I$(VINCD)/vltstd

CSRCS +=

CPPSRCS += \
	./main.cpp \
	./earliercon.cpp \
	./memsim.cpp \
	verilated.cpp \
	verilated_vcd_c.cpp

OBJS :=	$(CSRCS:%.c=$(OBJODIR)/%.o) \
		$(CPPSRCS:%.cpp=$(OBJODIR)/%.o)

OBJS += $(RTLOBJ)

$(RTLOBJ):
	@echo Building RTL
	make -f rtl.mk

$(OBJODIR)/%.o: %.c $(RTLOBJ)
	@echo [CC] $<
	@mkdir -p $(dir $@)
	@$(CC) $(COMMONFLAGS) $(CCFLAGS) $(INCLUDES) -c -o $@ $<

$(OBJODIR)/%.o: %.cpp $(RTLOBJ)
	@echo [CXX] $<
	@mkdir -p $(dir $@)
	@$(CXX) $(COMMONFLAGS) $(CPPFLAGS) $(INCLUDES) -c -o $@ $<

$(OBJODIR)/%.o: $(VINCD)/%.cpp
	@echo [CXX] $<
	@mkdir -p $(dir $@)
	@$(CXX) $(COMMONFLAGS) $(CPPFLAGS) $(INCLUDES) -c -o $@ $<

PHONY += all
all: $(OBJS)
	@$(LD) $(LDFLAGS) $(OBJS) $(LIBS) -o $(TARGET)
	@echo 'all finish'

PHONY += clean
clean:
	rm -rf $(OBJODIR)
	rm -f $(TARGET)
	make -f rtl.mk clean
	@echo 'clean finish'

# Declare the contents of the .PHONY variable as phony.  We keep that
# information in a variable so we can use it in if_changed and friends.
.PHONY: $(PHONY)

# Set default target
.DEFAULT_GOAL:= all

