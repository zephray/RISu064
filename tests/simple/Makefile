CROSS_COMPILE ?= riscv64-unknown-elf-
CC := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
RVEMU:= spike
RISUSIM:= ../sim/sim
CFLAGS:= -march=rv64i -mabi=lp64 -ffreestanding -nostdlib
SRCS = $(wildcard *.S)
ELF = $(SRCS:.S=.elf)
BIN = $(SRCS:.S=.bin)
EXPECTS = $(SRCS:.S=.expected)
ACTUALS = $(SRCS:.S=.actual)

.PHONY: all
all: elf bin expected actual result

.PHONY: elf
elf: $(ELF)

.PHONY: bin
bin: $(BIN)

.PHONY: expected
expected: $(EXPECTS)

.PHONY: actual
actual: $(ACTUALS)

%.actual: %.bin
	$(RISUSIM) $< --testmode

%.expected: %.elf
#	$(RVEMU) $< $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.elf: %.o
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,sections.lds,--strip-debug -o $@ $< -lgcc

%.o: %.S
	$(CC) -c $(CFLAGS) -o$@ $<

.PHONY: result
result:
	./compare.sh

.PHONY: clean
clean:
	rm -f *.o *.elf *.bin *.actual
