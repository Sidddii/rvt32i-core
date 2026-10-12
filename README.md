# RVT32I-Core: Internally Tagged RISC-V Processor

An implementation of the **RVT32I (Internally Tagged RISC-V)** architecture based on the 2-stage [NERV](https://github.com/YosysHQ/nerv) RV32I core.

This core augments the standard RISC-V integer datapath with physical register tagging and dynamic polymorphic execution semantics, as described in the RVT32I Frozen ISA Specification and research by Baig & Dalsgaard (DTU, 2026).

---

## Architecture Overview

Standard RISC-V processors rely on the instruction opcode to convey the data type of an operation (e.g. `LW` vs `LB`). RVT32I introduces **hardware register tags** that attach type metadata directly to register values:

- **Physical Tag Encoding:** 3-bit physical tag attached to each of the 32 general-purpose registers:
  - Bit 2: Signedness (`1` = Signed, `0` = Unsigned)
  - Bits [1:0]: Width (`00` = Byte/8-bit, `01` = Halfword/16-bit, `10` = Word/32-bit)
- **Active Tags:**
  - `u8`  (`3'b000`) — Unsigned 8-bit
  - `u16` (`3'b001`) — Unsigned 16-bit
  - `u32` (`3'b010`) — Unsigned 32-bit
  - `i8`  (`3'b100`) — Signed 8-bit
  - `i16` (`3'b101`) — Signed 16-bit
  - `i32` (`3'b110`) — Signed 32-bit (default/reset)
- **Zero-Register ($x_0$) Rule:** Hardwired to value `0` and tag `TAG_I32` (`3'b110`).
- **Canonical-Form Invariant (§3.5):** Narrow quantities written to registers are normalized to 32 bits based on their tag (sign-extended or zero-extended) at writeback, eliminating pre-ALU normalization muxes.

---

## Modular Submodule Structure

```
.
|-- tag_defs.vh             # Common tag definitions and encodings
|-- tag_regfile.sv          # 32 x 3-bit Tag Register File submodule
|-- tag_canonicalizer.sv    # Writeback canonical-form normalizer
|-- nerv.sv                 # Top-level RVT32I processor core
|-- testbench.sv            # Baseline testbench
|-- tag_testbench.sv        # Comprehensive RVT32I load verification testbench
|-- test_loads.s            # Assembly test suite for load instructions
`-- Makefile                # Build and simulation flow
```

---

## Verification & Testing

### Prerequisites
- `iverilog` (Icarus Verilog >= 12.0)
- `riscv64-elf-gcc` (RISC-V GCC toolchain with RV32I support)

### 1. Run Baseline Regression
```bash
make test
```
Simulates standard RV32I bare-metal firmware (`firmware.c`) to confirm backward compatibility.

### 2. Run Comprehensive Tagged Load Verification
```bash
make test_loads
```
Executes an 18-point verification test covering:
- Positive loads (`LB`, `LBU`, `LH`, `LHU`, `LW`)
- Negative/MSB-set loads (verifying sign-extension vs zero-extension)
- Byte and halfword memory alignment offsets (+0, +1, +2, +3)
- Back-to-back 2-cycle pipeline stress
- $x_0$ zero-register protection

Expected result:
```
==========================================================================
         RVT32I COMPREHENSIVE LOAD VERIFICATION SUITE
==========================================================================
  SUMMARY: 18 PASSED, 0 FAILED
  RESULT: >>> ALL TESTS PASSED (100%) <<<
==========================================================================
```

---

## References

- Baig & Dalsgaard, *Internally Tagged RISC-V*, Technical University of Denmark (DTU), 2026.
- RVT32I Frozen ISA Specification (DTU).
- Claire Wolf & N. Engelhardt, *NERV -- Naive Educational RISC-V Processor*, YosysHQ.
