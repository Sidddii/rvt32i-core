# RVT32I Core — Master's Thesis Project

This repository contains my Master's thesis project: implementing an **Internally Tagged RISC-V processor (RVT32I)** based on the 2-stage [NERV](https://github.com/YosysHQ/nerv) RV32I core.

The architecture is based on the research by Baig & Dalsgaard (DTU, 2026) and the RVT32I Frozen ISA specification.

---

## Project Goal

In standard RISC-V, instructions tell the CPU what type of data to process (e.g. `LW` for 32-bit word, `LB` for 8-bit byte).

The goal of this project is to move data type information **directly into the hardware registers** using a 3-bit tag for each register (`u8`, `u16`, `u32`, `i8`, `i16`, `i32`). This allows:

- **Polymorphic Execution:** The CPU can inspect register tags at runtime to decide store widths, shift modes, and comparisons automatically.
- **Smaller Code Size:** Fewer specialized instructions are needed in software.
- **Hardware Overhead Analysis:** Evaluating the area and clock frequency cost of adding tags compared to the baseline NERV processor.

---

## Implementation Roadmap

- [x] Baseline NERV setup and verification
- [x] 32x3-bit Tag Register File (`tag_regfile.sv`)
- [x] Writeback Canonicalizer (`tag_canonicalizer.sv`)
- [x] 2-cycle tagged loads (`LB`, `LBU`, `LH`, `LHU`, `LW`, `LWU`)
- [ ] Polymorphic store (`ST`)
- [ ] Explicit cast instructions (`CT*`)
- [ ] Tagged arithmetic promotion and tag-driven shifts
- [ ] Tagged branches and comparisons
- [ ] Tag spill and reload (`STAG` / `LTAG`)
- [ ] FPGA synthesis and area comparison

---

## How to Run Simulations

### Prerequisites

- `iverilog` (Icarus Verilog)
- `riscv64-elf-gcc` (RISC-V toolchain)

### Commands

```bash
# Run baseline regression (84 cycles)
make test

# Run RVT32I tagged load verification suite
make test_loads
```
