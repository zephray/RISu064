TARGET = coremark
BIN = $(TARGET).bin
ELF = $(TARGET).elf
DUMP = $(TARGET).dump
C_SRCS = $(wildcard *.c)
ASM_SRCS = $(wildcard *.S)
C_OBJS = $(C_SRCS:.c=.o)
ASM_OBJS = $(ASM_SRCS:.S=.o)
OBJS := $(ASM_OBJS) $(C_OBJS)
CFLAGS = -MD -O3 -mabi=lp64 -march=rv64im -mcmodel=medany -DTIME -DRISCV -DUSE_MYSTDLIB -DITERATIONS=20 -ffreestanding -nostdlib -Wl,--no-relax
TOOLCHAIN_PREFIX = riscv64-unknown-elf-

all: $(DUMP) $(BIN)

$(DUMP): $(ELF)
	$(TOOLCHAIN_PREFIX)objdump -d $< > $@

$(BIN): $(ELF)
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

$(ELF): $(OBJS) sections.lds
	$(TOOLCHAIN_PREFIX)gcc $(CFLAGS) -Wl,-Bstatic,-T,sections.lds,-Map,$(TARGET).map,--strip-debug -o $@ $(OBJS) -lgcc
	size $@

%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) $<

%.o: %.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) $<

clean:
	rm -rf *.o *.d *.elf *.map *.bin

.PHONY: clean

-include *.d

