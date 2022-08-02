TARGET = coremark
BIN = $(TARGET).bin
ELF = $(TARGET).elf
DUMP = $(TARGET).dump
C_SRCS = $(wildcard *.c)
ASM_SRCS = $(wildcard *.S)
C_OBJS = $(C_SRCS:.c=.o)
ASM_OBJS = $(ASM_SRCS:.S=.o)
OBJS := $(ASM_OBJS) $(C_OBJS)
CFLAGS = -MD -O3 -mabi=lp64 -march=rv64im -mcmodel=medany -DTIME -DRISCV -DUSE_MYSTDLIB -DITERATIONS=10 -ffreestanding -nostdlib -fno-common -funroll-loops -finline-functions -finline-limit=1000 -fno-if-conversion2 -fselective-scheduling -fno-crossjumping -freorder-blocks-and-partition
#CFLAGS = -MD -O3 -mabi=lp64 -march=rv64im -mcmodel=medany -DTIME -DRISCV -DUSE_MYSTDLIB -DITERATIONS=1 -ffreestanding -nostdlib
#CFLAGS = -MD -O2 -mabi=lp64 -march=rv64im -mcmodel=medany -DTIME -DRISCV -DUSE_MYSTDLIB -DITERATIONS=10 -ffreestanding -nostdlib -fno-common -funroll-loops -finline-functions --param max-inline-insns-auto=20 -falign-functions=4 -falign-jumps=4 -falign-loops=4
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

