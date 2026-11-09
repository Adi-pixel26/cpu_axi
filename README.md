# CPU_AXI — RV32IM Pipelined CPU with 4-Way L1 Caches and AXI4 SDRAM

[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32IM-ef5350)](#cpu-core)
[![HDL](https://img.shields.io/badge/HDL-Verilog-2f74c0)](#repository-layout)
[![FPGA](https://img.shields.io/badge/FPGA-Terasic%20DE10--Lite-0067a5)](#target-hardware)
[![Tools](https://img.shields.io/badge/Tools-Quartus%20Prime%2020.1%20%7C%20ModelSim-6a1b9a)](#simulation-and-verification)

CPU_AXI is a from-scratch, FPGA-oriented 32-bit RISC-V computer system. It combines a five-stage RV32IM pipeline, split four-way set-associative L1 caches, a custom single-beat AXI4 master, Intel Platform Designer's AXI-to-Avalon interconnect, external SDRAM, and memory-mapped FPGA peripherals.

The current board target is the **Terasic DE10-Lite** with an Intel MAX 10 FPGA and 64 MiB of onboard SDR SDRAM.

## Highlights

- Five-stage **IF → ID → EX → MEM → WB** pipeline.
- RV32I base integer ISA plus the RV32M multiply/divide extension.
- Forwarding, load-use interlocks, branch/jump flushing, and cache-driven pipeline stalls.
- Separate **16 KiB I-cache and 16 KiB D-cache**—32 KiB of L1 cache in total.
- Four-way set associativity, 128 sets, 32-byte lines, and tree pseudo-LRU replacement.
- Write-back, write-allocate D-cache with dirty eviction and full-cache flush support.
- Single-beat, five-channel AXI4 master connected to an AXI-to-Avalon SDRAM subsystem.
- Uncached FPGA MMIO region with a CPU-controlled LED peripheral.
- Standalone 640×480 VGA timing controller and 25 MHz PLL included for graphics expansion.
- Bare-metal firmware toolchain, startup code, linker script, and FPGA loader utilities.
- Self-checking ModelSim testbenches for the CPU/cache/AXI path, control-flow hazards, and AXI backpressure.

## System architecture

```text
                         +-----------------------------+
                         |      Five-stage RV32IM      |
                         | IF | ID | EX | MEM | WB     |
                         +-------------+---------------+
                                       |
                         instruction   |   load/store
                              |        |        |
                              v        |        v
                    +----------------+ | +----------------+
                    | 16 KiB L1 I$   | | | 16 KiB L1 D$   |
                    | 4-way, 32 B    | | | 4-way, 32 B    |
                    +--------+-------+ | +--------+-------+
                             \         |         /
                              +--------+--------+
                                       |
                              I/D memory arbiter
                                       |
                                cache/AXI bridge
                                       |
                            32-bit single-beat AXI4
                                       |
                      Platform Designer AXI-to-Avalon
                                       |
                            64 MiB onboard SDRAM

              Data accesses in 0x04xx_xxxx bypass the D-cache
                                       |
                               FPGA-local MMIO
                                       |
                             CPU-controlled LEDs
```

## CPU core

The processor implements the classic five pipeline stages:

1. **Instruction Fetch** — program-counter update and instruction-cache access.
2. **Instruction Decode** — instruction decode, register-file reads, and immediate generation.
3. **Execute** — ALU operations, branch evaluation, multiplication, and iterative division.
4. **Memory** — aligned byte, halfword, and word load/store requests.
5. **Writeback** — ALU, memory, or PC-relative result selection.

The hazard unit supports EX/MEM and MEM/WB forwarding, inserts a bubble for load-use dependencies, and flushes younger instructions after taken branches, `JAL`, and `JALR`. A blocking cache miss freezes the pipeline until the required instruction and data responses are available. Multi-cycle divide and remainder instructions hold the Execute stage while older instructions finish normally.

Implemented RV32M operations include `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, and `REMU`. The iterative divider also handles divide-by-zero and signed-overflow cases defined by the RISC-V specification.

## Cache and memory subsystem

| Property | L1 instruction cache | L1 data cache |
| --- | --- | --- |
| Capacity | 16 KiB | 16 KiB |
| Associativity | 4-way | 4-way |
| Sets | 128 | 128 |
| Line size | 32 bytes / 8 words | 32 bytes / 8 words |
| Replacement | Tree pseudo-LRU | Tree pseudo-LRU |
| Write policy | Read-only | Write-back, write-allocate |
| Maintenance | Full invalidation | Dirty writeback and full flush |

The caches use ready/valid request and response interfaces. A D-cache-priority arbiter shares the lower-memory path, while `cache_axi_bridge.v` converts each cache word transfer into a transaction for `axi_master.v`. Cache-line refill and writeback currently use eight 32-bit single-beat transactions.

At the board level, Intel Platform Designer translates AXI4 into Avalon-MM, performs the 32-bit-to-16-bit width adaptation, and drives the DE10-Lite SDRAM controller.

## Memory map

| Address range | Size | Purpose |
| --- | ---: | --- |
| `0x0000_0000`–`0x03FF_FFFF` | 64 MiB | External SDRAM; cached instruction and data memory |
| `0x0400_0000` | 4 bytes | FPGA LED register; uncached local MMIO |
| `0x0400_0004`–`0x04FF_FFFF` | Reserved | Future FPGA peripherals |

A store to `0x0400_0000` updates six user LEDs. A load from the same address reads the register back. These accesses bypass the D-cache and do not enter the SDRAM interconnect.

## FPGA integration

### Target hardware

- Board: Terasic DE10-Lite
- FPGA: Intel MAX 10 `10M50DAF484C7G`
- Input and system clock: 50 MHz
- External memory: 64 MiB, 16-bit SDR SDRAM
- Toolchain: Intel Quartus Prime Lite 20.1 and ModelSim Intel FPGA Edition
- Quartus top-level entity: `de10lite_cpu_sdram_top`

`KEY[0]` resets the board, `SW0` resets the CPU, and `KEY[1]` requests a safe debug halt. During a debug halt, the controller drains in-flight traffic, writes back and invalidates the D-cache, invalidates the I-cache, and then holds the pipeline so SDRAM can be inspected safely.

The VGA directory contains a 25 MHz PLL and a 640×480 timing generator. The controller is included in the Quartus project, but a CPU-visible framebuffer and final VGA connection to `de10lite_cpu_sdram_top` are still in progress.

## Bare-metal firmware

The `firmware/` directory contains:

- `startup.S` for reset entry and stack initialization.
- `linker.ld` for the bare-metal memory layout.
- `main.c` for C execution, stack, BSS, multiply/divide, SDRAM, and MMIO checks.
- `Makefile` for building with a RISC-V GNU toolchain.
- `load_firmware.tcl` and `make_loader.py` for loading an image through the FPGA debug path.
- Prebuilt ELF, binary, hexadecimal, map, and disassembly artifacts.

The checked-in firmware currently performs CPU and MMIO validation and leaves the six CPU-controlled LEDs on after a successful run.

## Simulation and verification

The design includes self-checking tests rather than waveform-only demonstrations. The following tests were run successfully with ModelSim Intel FPGA Edition 20.1:

| Testbench | Coverage | Result |
| --- | --- | --- |
| `tb_cached_riscv_cpu.v` | CPU, load/store adapter, I/D caches, arbiter, cache maintenance, AXI bridge/master | PASS |
| `tb_pc_redirect.v` | Forwarding into `JALR`/`BEQ`, link values, redirection, and pipeline flush | PASS |
| `tb_axi_sdram_memtest.v` | Independent AXI address/data handshakes and deterministic backpressure | PASS |

### Run the main integration test

From PowerShell:

```powershell
cd code
vlib work

$rtl = Get-ChildItem components -Filter *.v | ForEach-Object FullName
$rtl += @(
  'load_store_adapter.v', 'l1_icache_4way.v', 'l1_dcache_4way.v',
  'cache_memory_arbiter.v', 'cache_axi_bridge.v', 'axi_master.v',
  'axi_slave_mem.v', 'riscv_cpu.v', 'cached_riscv_cpu_top.v',
  'tb_cached_riscv_cpu.v'
)
$rtl | ForEach-Object { vlog -quiet -work work $_ }

vsim -c -lib work tb_cached_riscv_cpu -do "run -all; quit -f"
```

Expected final message:

```text
PASS cached CPU, load/store adapter, arbiter, and AXI path
```

The full board-level SDRAM simulation additionally uses the generated Platform Designer simulation model.

## Build for the DE10-Lite

1. Open `cpu_axi.qpf` in Quartus Prime Lite 20.1.
2. Open `code/sdram_system_1.qsys` in Platform Designer and regenerate the system if its generated output is missing or out of date.
3. Confirm that `de10lite_cpu_sdram_top` is selected as the top-level entity.
4. Run **Processing → Start Compilation**.
5. Program the generated `output_files/cpu_axi.sof` with the Quartus Programmer and USB-Blaster.
6. Press `KEY[0]` to reset and start the system.

Generated Quartus databases, simulator work libraries, waveforms, and programming files are excluded through `.gitignore`.

## Repository layout

```text
cpu_axi/
├── code/
│   ├── components/               # Pipeline, decoder, ALU, hazard, and RV32M units
│   ├── code/                     # Generated Platform Designer HDL
│   ├── vga/                      # VGA PLL and 640×480 timing controller
│   ├── riscv_cpu.v               # CPU integration
│   ├── cached_riscv_cpu_top.v    # CPU, caches, MMIO split, arbiter, and AXI
│   ├── l1_icache_4way.v          # 16 KiB instruction cache
│   ├── l1_dcache_4way.v          # 16 KiB data cache
│   ├── axi_master.v              # Single-beat AXI4 master
│   └── tb_*.v                    # Self-checking testbenches
├── firmware/                     # Bare-metal C/assembly, linker, build, and load files
├── cpu_axi.qpf                   # Quartus project
├── cpu_axi.qsf                   # Device, pin, and source assignments
├── cpu_axi.sdc                   # Timing constraints
└── README.md
```

## Current limitations

- Both caches are blocking, and the shared lower-memory path permits one outstanding transaction.
- Cache-line transfers use eight word transactions instead of AXI bursts.
- Exceptions, interrupts, CSRs, and privilege modes are not yet implemented.
- The VGA timing block is present, but the framebuffer and board-top integration are not complete in this branch.
- Tetris, Doom, and an operating-system image are not yet included in this repository.

## Roadmap

- Connect the VGA controller to a memory-mapped framebuffer and input peripherals.
- Add the Tetris software demo and reproducible FPGA run instructions.
- Add UART, a timer, interrupts, CSRs, and exception/trap handling.
- Boot a small bare-metal monitor, followed by a minimal custom operating system.
- Explore the ISA, memory, and graphics improvements needed for a Doom-class workload.
- Add assertions, randomized cache/AXI backpressure tests, and functional coverage.

## Author

**Adithya Linga**

[GitHub](https://github.com/Adi-pixel26) · [LinkedIn](https://linkedin.com/in/adithya-linga-2a8777334)
