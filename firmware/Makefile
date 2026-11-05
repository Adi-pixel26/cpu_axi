.RECIPEPREFIX := >

RISCV_PREFIX := riscv64-unknown-elf-

CC      := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump
SIZE    := $(RISCV_PREFIX)size

CFLAGS := \
    -march=rv32im \
    -mabi=ilp32 \
    -mcmodel=medany \
    -mno-relax \
    -msmall-data-limit=0 \
    -O1 \
    -std=c11 \
    -ffreestanding \
    -fno-builtin \
    -fno-stack-protector \
    -ffunction-sections \
    -fdata-sections

LDFLAGS := \
    -nostdlib \
    -nostartfiles \
    -Wl,-T,linker.ld \
    -Wl,-Map,firmware.map \
    -Wl,--gc-sections

.PHONY: all build clean inspect

all: build

build: firmware.elf firmware.bin firmware.dis load_firmware.tcl
>$(SIZE) -A firmware.elf
>echo "Build complete."
>echo "System Console command:"
>echo "source {C:/quartus_proj/cpu_axi/firmware/load_firmware.tcl}"

firmware.elf: startup.S main.c linker.ld
>$(CC) $(CFLAGS) $(LDFLAGS) -o firmware.elf startup.S main.c -lgcc

firmware.bin: firmware.elf
>$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.dis: firmware.elf
>$(OBJDUMP) -d -S firmware.elf > firmware.dis

load_firmware.tcl: firmware.bin make_loader.py
>python3 make_loader.py

inspect: firmware.elf
>$(OBJDUMP) -h firmware.elf
>$(OBJDUMP) -d -S firmware.elf | less
>$(SIZE) -A firmware.elf

clean:
>rm -f firmware.elf firmware.bin firmware.dis firmware.map load_firmware.tcl