# 32-bit Pipelined RISC-V (RV32I) Processor with 4-Way Set-Associative L1 Caches & AXI4 SDRAM Subsystem

[![Target FPGA](https://img.shields.io/badge/FPGA-Intel%20MAX%2010%20(10M50DAF484C7G)-blue.svg)](#target-hardware-de10-lite)
[![Architecture](https://img.shields.io/badge/ISA-RISC--V%20RV32I%20(5--Stage%20Pipeline)-orange.svg)](#cpu-core-architecture)
[![Bus Protocol](https://img.shields.io/badge/Bus-AMBA%20AXI4-green.svg)](#axi4-bus-interface)
[![Toolchain](https://img.shields.io/badge/Tools-Quartus%20Prime%20%7C%20ModelSim-purple.svg)](#simulation--verification)

This repository contains the complete synthesizable Verilog implementation, testbenches, and Intel Quartus Prime project for a high-performance **32-bit RISC-V (RV32I) Pipelined Processor**. The processor features **split 16 KiB 4-way set-associative L1 caches**, a **cache-to-AXI bridge**, a **5-channel AXI4 master interface**, and an **onboard 64 MB SDRAM memory controller** targeted for the **Terasic DE10-Lite FPGA**.

---

## Architecture Overview

```
                      +-------------------------------------------------+
                      |              de10lite_cpu_sdram_top             |
                      |                                                 |
                      |  +-------------------------------------------+  |
                      |  |           cached_riscv_cpu_top            |  |
                      |  |                                           |  |
+------------------+  |  |  +---------------------+                  |  |
|                  |  |  |  |      riscv_cpu      |                  |  |
|  MAX10_CLK1_50   |---->|  | (5-Stage Pipelined) |                  |  |
|  (50 MHz Osc)    |  |  |  +----------+----------+                  |  |
|                  |  |  |       Fetch | | Mem/Writeback             |  |
+------------------+  |  |             v v                           |  |
                      |  |    +--------+-------+                     |  |
+------------------+  |  |    |  L1 I-Cache    |  L1 D-Cache         |  |
|   Pushbuttons    |  |  |    | (16KB, 4-Way)  | (16KB, 4-Way)       |  |
|   (Reset / KEY)  |---->|    +--------+-------+-------+             |  |
+------------------+  |  |             |               |             |  |
                      |  |             v               v             |  |
                      |  |      +--------------+-------------+       |  |
                      |  |      |    cache_memory_arbiter    |       |  |
                      |  |      +--------------+-------------+       |  |
                      |  |                     |                     |  |
                      |  |                     v                     |  |
                      |  |      +--------------+-------------+       |  |
                      |  |      |      cache_axi_bridge      |       |  |
                      |  |      +--------------+-------------+       |  |
                      |  |                     |                     |  |
                      |  |                     v                     |  |
                      |  |      +--------------+-------------+       |  |
                      |  |      |         axi_master         |       |  |
                      |  |      +--------------+-------------+       |  |
                      |  +---------------------|---------------------+  |
                      |                        | AXI4 (5 Channels)      |
                      |                        v                        |
                      |  +-------------------------------------------+  |
                      |  |        Platform Designer (Qsys)           |  |
                      |  |   sdram_system_1 (AXI-to-Avalon Bridge)   |  |
                      |  |       + SDRAM Memory Controller           |  |
                      |  +---------------------+---------------------+  |
                      +------------------------|------------------------+
                                               |
                                               v
                                   +-----------------------+
                                   |   64 MB SDR SDRAM     |
                                   |    (IS42S16320D)      |
                                   +-----------------------+
```

---

## Key Features

### 1. CPU Core (`riscv_cpu.v`)
* **ISA:** Standard RV32I Base Integer Instruction Set (Arithmetic, Logic, Shifts, Branches, Jumps, Loads, Stores).
* **Pipeline Stages:** Classical 5-stage pipeline:
  1. **IF (Instruction Fetch):** PC generation, instruction retrieval, branch target redirection.
  2. **ID (Instruction Decode):** Instruction decoding, register file read, immediate extension.
  3. **EX (Execute):** 32-bit ALU operations, branch condition evaluation.
  4. **MEM (Memory):** Load/store generation, data memory alignment.
  5. **WB (Writeback):** Register writeback selection.
* **Hazard Resolution:**
  * **Data Forwarding Unit (`forward_unit.v`):** Resolves EX-to-EX and MEM-to-EX data dependencies with zero stall overhead.
  * **Hazard Detection Unit (`hazard_unit.v`):** Detects load-use dependencies and injects pipeline bubbles (stalls).
  * **Branch / Jump Flushing:** Evaluates branch outcomes in EX stage and flushes mispredicted speculative instructions (`FlushD`, `FlushE`).
  * **Cache Stall Support:** Dynamic pipeline freeze via `ICacheStall` and `DCacheStall` inputs during cache misses.

### 2. L1 Cache Subsystem
* **L1 Instruction Cache (`l1_icache_4way.v`):**
  * **Capacity:** 16 KiB
  * **Organization:** 4-Way Set-Associative
  * **Line Size:** 32 Bytes (8 × 32-bit words per line)
  * **Number of Sets:** 128 sets
  * **Replacement Policy:** Tree Pseudo-LRU (PLRU)
  * **Access:** Read-only, blocking
  * **Invalidation:** Hardware `invalidate_all` support for future `FENCE.I` execution.
* **L1 Data Cache (`l1_dcache_4way.v`):**
  * **Capacity:** 16 KiB
  * **Organization:** 4-Way Set-Associative
  * **Line Size:** 32 Bytes (8 × 32-bit words per line)
  * **Write Policy:** Write-Back with Write-Allocate (uses dirty-bit tracking to minimize external memory bus traffic).
  * **Byte-Masking:** Supports unaligned and sub-word accesses (`SB`, `SH`, `SW`) via byte write strobes (`wstrb`).
  * **Hardware Flush Interface:** Writes back all dirty cache lines to external memory and invalidates entries.

### 3. Interconnect & AXI4 Bus Master
* **Cache Memory Arbiter (`cache_memory_arbiter.v`):** Arbitrates simultaneous memory refill requests from the I-Cache and D-Cache with priority management.
* **Cache-to-AXI Bridge (`cache_axi_bridge.v`):** Packs/unpacks 32-byte cache line bursts into discrete 32-bit word transactions.
* **AXI4 Bus Master (`axi_master.v`):** Full hardware implementation of standard AMBA AXI4 protocol:
  * **AW (Write Address):** `AWADDR`, `AWVALID`, `AWREADY`
  * **W (Write Data):** `WDATA`, `WSTRB`, `WVALID`, `WREADY`
  * **B (Write Response):** `BRESP`, `BVALID`, `BREADY`
  * **AR (Read Address):** `ARADDR`, `ARVALID`, `ARREADY`
  * **R (Read Data):** `RDATA`, `RRESP`, `RVALID`, `RREADY`

### 4. Target Hardware (DE10-Lite)
* **FPGA Device:** Intel MAX 10 `10M50DAF484C7G`
* **SDRAM Memory:** 64 MB (32M × 16 bits) High-Speed SDRAM (IS42S16320D)
* **Phase-Locked Loop (`de10lite_sdram_pll.v`):**
  * Generates synchronized core `system_clk` and phase-shifted `sdram_clk` to guarantee external setup and hold timing margins.
* **Reset Synchronizer:** Dual-flip-flop asynchronous assert / synchronous de-assert reset circuit tied to `KEY[0]`.

---

## Project Structure

```
cpu_axi/
├── README.md                      # Comprehensive project documentation
├── .gitignore                     # Git ignore rules for Quartus Prime & ModelSim
├── cpu_axi.qpf                    # Intel Quartus Prime Project File
├── cpu_axi.qsf                    # Pin assignments, timing constraints & project settings
├── cpu_axi.sdc                    # Synopsys Design Constraints (Clock definitions)
├── sdram_system_1.sopcinfo        # Qsys / Platform Designer system configuration
│
└── code/
    ├── cached_riscv_cpu_top.v     # Integrated CPU Subsystem Top
    ├── de10lite_cpu_sdram_top.v   # Complete Board-Level FPGA Top Module
    ├── de10lite_sdram_pll.v       # PLL clock generator for core & SDRAM
    │
    ├── riscv_cpu.v                # Pipelined 32-bit RV32I processor core
    ├── pl_riscv_cpu.v             # Pipelined CPU wrapper
    ├── t1_riscv_cpu.v             # Test CPU wrapper
    │
    ├── l1_icache_4way.v           # 16 KiB 4-way set-associative L1 I-Cache
    ├── l1_dcache_4way.v           # 16 KiB 4-way set-associative L1 D-Cache
    ├── l1_icache_2way.v           # Alternative 2-way I-Cache variant
    ├── cache_memory_arbiter.v     # Dual-cache request arbiter
    ├── cache_axi_bridge.v         # Cache line-to-AXI translation bridge
    ├── load_store_adapter.v       # Load/Store data alignment adapter
    │
    ├── axi_master.v               # 5-channel AMBA AXI4 Master interface
    ├── axi_slave_mem.v            # Synthesizable/Behavioral AXI slave memory model
    ├── axi_sdram_memtest.v        # Hardware memory pattern tester
    │
    ├── components/                # Modular CPU Datapath Building Blocks
    │   ├── adder.v                # 32-bit ripple/carry adder
    │   ├── alu.v                  # Arithmetic Logic Unit
    │   ├── alu_decoder.v          # ALU operation decoder
    │   ├── branching_unit.v       # Branch condition evaluator
    │   ├── controller.v           # Pipeline control unit
    │   ├── datapath.v             # Complete CPU datapath
    │   ├── hazard_unit.v          # Hazard detection & forwarding control
    │   ├── imm_extend.v           # Sign-extension unit (I, S, B, U, J types)
    │   ├── main_decoder.v         # Main opcode decoder
    │   ├── mux2.v, mux3.v, mux4.v # Parameterized multiplexers
    │   ├── pl_reg_*.v             # Pipeline inter-stage registers (FD, DE, EM, MW)
    │   ├── reg_file.v             # 32 x 32-bit Dual-Port Register File (x0 = 0)
    │   └── reset_ff.v             # Reset flip-flops
    │
    ├── code/                      # Qsys Platform Designer Generated System
    │   └── sdramsystem_1/         # SDRAM Controller synthesis and wrapper files
    │
    └── testbenches & tests/       # Verification Suites
        ├── tb_cached_riscv_cpu.v  # Full CPU + Cache + AXI system testbench
        ├── tb_cpu_sdram_system_1.v# CPU + Qsys SDRAM system integration testbench
        ├── tb_axi_sdram_memtest.v # AXI SDRAM memory stress testbench
        ├── tb_pc_redirect.v       # Branch prediction & flush verification
        ├── tb_custom.v            # Custom instruction testbench
        └── *.hex, *.s             # Assembly test routines & compiled machine code
```

---

## Memory & Cache Specifications

| Parameter | Instruction Cache (L1 I$) | Data Cache (L1 D$) |
| :--- | :--- | :--- |
| **Total Size** | 16 KiB | 16 KiB |
| **Associativity** | 4-Way Set-Associative | 4-Way Set-Associative |
| **Line Size** | 32 Bytes (8 words) | 32 Bytes (8 words) |
| **Number of Sets** | 128 Sets | 128 Sets |
| **Replacement** | Tree Pseudo-LRU (PLRU) | Tree Pseudo-LRU (PLRU) |
| **Write Policy** | Read-Only (Fetch only) | Write-Back with Write-Allocate |
| **Sub-word Writes** | N/A | Supported (Byte, Half-word, Word via `wstrb`) |
| **Flush Support** | Hardware Invalidation (`invalidate_all`) | Hardware Write-Back & Clean Flush |

---

## Simulation & Verification

The processor includes self-checking testbenches verifiable with **ModelSim** or **QuestaSim**:

### Running Integration Simulation (`tb_cached_riscv_cpu.v`)
```bash
# Navigate to code directory
cd code

# Create work library
vlib work

# Compile components, caches, CPU, and testbench
vlog components/*.v
vlog l1_icache_4way.v l1_dcache_4way.v cache_memory_arbiter.v cache_axi_bridge.v
vlog axi_master.v axi_slave_mem.v riscv_cpu.v cached_riscv_cpu_top.v
vlog tb_cached_riscv_cpu.v

# Run self-checking simulation
vsim -c tb_cached_riscv_cpu -do "run -all; quit -f"
```

The testbench runs assembly verification programs (`rv32i_test.hex`), validating:
1. RAW hazard forwarding across pipeline stages.
2. Load-use pipeline interlocks (stalls).
3. Branch taken/not-taken redirections and pipeline flushes.
4. Cache hits, cold misses, line refills, and dirty line writeback bursts through the AXI bus.

---

## FPGA Synthesis (Intel Quartus Prime)

1. Open **Intel Quartus Prime** (Lite / Standard Edition).
2. Click **File -> Open Project** and select `cpu_axi.qpf`.
3. Open **Platform Designer (Qsys)** if modifying the SDRAM interface:
   * Load `code/code/sdramsystem_1/sdram_system_1.qsys` and generate HDL.
4. Run Compilation (**Processing -> Start Compilation** or `Ctrl + L`).
5. Program the **Terasic DE10-Lite FPGA**:
   * Open **Programmer**, detect USB-Blaster.
   * Load `output_files/cpu_axi.sof` and click **Start**.

---

## Author & License

* **Developer:** Adithya Linga ([@Adi-pixel26](https://github.com/Adi-pixel26))
* **License:** MIT License — feel free to use and adapt for academic and development projects.
