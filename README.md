# RV32I Core: RTL and Verification

This repository presents a single-cycle RV32I RISC-V core and its full verification environment, both built from scratch. I designed and wrote the RTL from a custom Microarchitecture Specification, then verified it using instruction-level co-simulation against the Spike golden model, SystemVerilog Assertions, functional coverage closure, and exhaustive formal proofs through riscv-formal. A living Bug-Hunt Log records every RTL defect the environment caught, root-caused, and closed.

---

## Architecture

The core executes the full RV32I base integer instruction set in a single cycle per instruction, with no pipelining and no CSR support in this stage. Memory access runs over two independent, decoupled request-response ports, one for instruction fetch and one for data, each supporting variable response latency and backpressure so timing correctness can be verified independently of program content. A Retirement Observation Port reports the architectural effect of every retired instruction and serves as the sole interface for both verification methods: the co-simulation scoreboard and the riscv-formal property set.

---

## Verification Results and Sign-off Metrics

*   **Regression Status:** PASS
    *   128,817 retirements checked across the full regression: 15 directed and fault tests in both zero-wait-state and randomized memory timing, plus 100 randomly generated programs of 2,000 instructions each.
    *   0 scoreboard mismatches.
*   **SystemVerilog Assertions:** 40 active properties, over 40.3 million dynamic evaluations, 0 failures.
*   **Formal Verification:** All 44 riscv-formal checks pass, covering per-instruction state transition proofs, register-read correctness, retirement ordering, causality, and liveness.
*   **Functional Coverage:**
    *   97.4% on the instruction and retirement covergroup, with the remainder covered by five documented waivers for structurally unreachable bins.
    *   100% on the memory-timing covergroup.
*   **Bugs Captured:** 6 RTL bugs isolated, root-caused, and fixed. Details are logged in the [Bug-Hunt Log](docs/vPlan.md#13-bug-hunt-log).
*   **Coverage Waivers & Traceability:** Every coverage gap structurally unreachable by dynamic simulation is documented in the [Waivers table](docs/vPlan.md#11-waivers) with its specific unreachability reason and closing disposition.

---

## Verification Environment and Methodology

The verification environment is a SystemVerilog testbench using mailboxes for transaction communication between the retirement monitor, the golden trace adapter, and the scoreboard.

*   **Stimulus Generation:** Hand-written directed programs target specific instruction corners and fault conditions. A constrained-random program generator produces legal instruction streams biased toward register aliasing, immediate-value corners, and arithmetic boundaries.
*   **Checking Mechanism:** A self-checking scoreboard compares the core's retirement stream against a golden commit log produced by Spike, checking register writes, memory addresses, byte strobes, and PC updates on every retirement.
*   **Timing Independence:** A memory timing agent randomizes response latency and request backpressure independently per port, and every test replays under both zero-wait-state and randomized timing to prove stalling cannot alter architectural behavior.
*   **Protocol Assertions:** Concurrent SystemVerilog Assertions monitor the memory bus protocol and internal design invariants continuously across every test.
*   **Formal Verification:** riscv-formal proves each instruction's RVFI-reported state transition against the ISA definition exhaustively within a bounded depth, independent of any test program.
*   **Functional Coverage:** Covergroups track instruction coverage, operand aliasing, ALU and shift corners, load/store alignment, fault causes, and memory-timing crossed against instruction type. The full regression runs inside a single simulation against one coverage database, so the reported percentage is exact rather than a bound merged from separate runs.

---

## Quick Start

### Prerequisites
*   Simulation Tool: `dsim` (Altair DSim)
*   Golden Reference Model: `spike`
*   RISC-V Toolchain: `riscv64-unknown-elf-gcc`
*   Formal Tool: `sby` (SymbiYosys)

### Run a Single Directed Test
```bash
make test_smoke
```

### Run the Full Directed and Fault Suite
```bash
make regression
```

### Run the Complete Regression for an Exact Coverage Signoff
```bash
make coverage_signoff
```

### Run the Formal Proofs
```bash
make formal
```

### Clean Up Artifacts
```bash
make clean
```

---

## Repository Layout

*   [rtl/](rtl) - Core RTL: datapath, controller, ALU, decoders, load-store unit, fault control, register file.
*   [dv/](dv) - Verification environment:
    *   [dv/env/](dv/env) - Memory model, memory-timing agent, RVFI monitor, bus monitors, Spike trace adapter, and scoreboard.
    *   [dv/cov/](dv/cov) - Functional coverage groups.
    *   [dv/sva/](dv/sva) - Bound assertions for the memory bus protocol and internal design invariants.
*   [sw/tests/](sw/tests) - Directed assembly and C test programs.
*   [scripts/](scripts) - Random program generator and regression summary tool.
*   [formal/](formal) - riscv-formal harness and per-instruction proof checks.
*   [docs/](docs) - Architectural Specifications & Verification Planning:
    *   [Microarchitecture Specification (MAS)](docs/MAS.md)
    *   [Verification Plan (vPlan)](docs/vPlan.md)
