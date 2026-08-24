# RV32I Core Verification Plan (vPlan)

This document defines the verification strategy, testbench architecture, formal proof plan, functional coverage targets, and sign-off criteria for the single-cycle RV32I core specified in [MAS.md](./MAS.md).

![DV Environment Topology](./dv_environment.png)

---

## 1. Verification Strategy

The core is verified by two independent methods against two independent references. Neither subsumes the other, and both are required for sign-off.

| Layer | Reference | Proves | Limitation |
|---|---|---|---|
| **ISA co-simulation** | Spike, the reference RISC-V ISA simulator | That the core's architectural state transitions match the golden model for every instruction of every program executed. | Stimulus-limited. Only proves conformance over the states the test programs actually reach. |
| **`riscv-formal`** | The `riscv-formal` per-instruction property set, driven by the RVFI port | That each instruction's state transition is ISA-correct across *all* reachable states within the model-checking bound. | Bounded. Proves nothing beyond the depth the solver reaches, and says nothing about whole-program behavior. |

Co-simulation is brought up first. It is the bring-up and debug loop: a divergence report names the retirement index, the architectural field that differs, and both values, which localizes a defect to one instruction without waveform archaeology. A core passing co-simulation on the full program suite is a complete, self-contained deliverable.

`riscv-formal` is applied second, to an already-working core. Its cost is concentrated in one-time harness bring-up — wiring the RVFI port into the formal wrapper and configuring SymbiYosys — and that cost is paid here, on the single-cycle core with the simplest possible retirement behavior, so that it amortizes onto the pipelined successor.

**Guardrail:** the `riscv-formal` bring-up is time-boxed. Co-simulation sign-off (§12) does not depend on it. A stalled formal harness delays the formal criterion only; it never blocks the co-simulation deliverable.

A third layer — hand-written SVA on the core's own boundary and internal invariants (§6) — runs continuously under both, and covers what neither reference checks: the memory bus protocol, and the internal structural properties that are the core's own design intent rather than an ISA requirement.

---

## 2. Environment Architecture

The verification environment is a transaction-level, layered SystemVerilog testbench. It uses virtual interfaces for physical DUT coupling and mailboxes for transaction communication, matching the structure used in the companion SPI and AXI4-Lite projects.

The core is not driven by a stimulus driver in the conventional sense. Its stimulus is a *program*: the environment loads an executable into the memory model and lets the core fetch it. Stimulus quality is therefore a property of the program generator (§9), not of a transaction driver. What the environment does drive is the *timing* of the memory system, which is randomized independently of program content.

**Components:**
*   **Program Loader**: Parses a linked ELF image, writes its loadable segments into the memory model's backing store, and resolves the entry point and any symbols the test requires.
*   **Memory Model**: A sparse associative-array store serving both core ports (§3).
*   **Memory Timing Agent**: Randomizes `req_ready` deassertion and response latency independently per port, per transaction (§6, C5).
*   **RVFI Retirement Monitor**: Samples the retirement observation port and packs each retirement into a transaction object (§4).
*   **Memory Bus Monitors**: Passive observers on the instruction and data ports (§4).
*   **Golden Trace Adapter**: Normalizes the reference simulator's commit log into the same transaction format the retirement monitor produces (§3).
*   **Instruction Stream Generator**: Emits randomized legal RV32I assembly programs (§9).
*   **Scoreboard** and **Coverage Collector**.

---

## 3. Reference Models

### 3.1 Golden ISA Model — Spike

Spike is the golden architectural reference. It is not reimplemented in the testbench; it is invoked as an external tool and its output is consumed.

*   **Committed approach — offline trace comparison.** Spike executes the same ELF image with `--isa=RV32I` and commit logging enabled, producing an instruction-by-instruction record of retirements: program counter, instruction word, register writes, and memory accesses. The Golden Trace Adapter parses this into a stream of retirement transactions, which the scoreboard consumes in lock-step with the stream from the RVFI monitor. This requires no DPI, no linking against the simulator's internals, and no patched build, which makes it the correct starting point.
*   **Documented upgrade path — DPI lock-step.** Spike is built as a shared library and stepped one instruction at a time from the testbench through DPI-C, with its state compared at each retirement. This is required only when the reference must react to the design's behavior rather than merely be compared against it — interactive memory-mapped I/O, or interrupts. Neither is in scope for this core, so the upgrade is deferred and noted here as the known next step rather than built speculatively.

**Reference boundary.** Spike's commit log reports architectural *writes* — the destination register and its new value, and memory accesses — not register *reads*. Consequently the co-simulation scoreboard checks the fields in §5 and does not check `rvfi_rs1_rdata` / `rvfi_rs2_rdata`. Register read correctness is proven separately by the `riscv-formal` `reg` check (§7), which is the mechanism that exists for exactly this purpose. This split is deliberate and is the reason both layers are required.

### 3.2 Memory Model

A behavioral model of the memory system, shared by both core ports over one address space.

*   **Backing store**: Sparse associative array, so an unbounded address space costs only what a program touches.
*   **Protocol**: Implements the request-response contract of MAS §6, honoring `wstrb` byte lanes on writes and returning the full addressed word on reads.
*   **Timing**: Wait states and response latency are supplied by the Memory Timing Agent, not fixed. The model is capable of zero-wait-state operation for initial bring-up and arbitrary-latency operation for stall verification.
*   **Simulation control**: Implements `SIM_EXIT` and `SIM_PUTC` (MAS §9). A `SIM_EXIT` write ends the test and reports the exit code.
*   **Uninitialized-read policy**: A read of an address never written is flagged as a test error, not silently zero-filled. Spike's behavior at such an address would not be guaranteed to match, so this is a stimulus defect that must surface as one.

---

## 4. Passive Monitors

*   **RVFI Retirement Monitor**: Samples the full retirement observation port on each cycle where `rvfi_valid` is asserted and forwards one transaction per retirement to the scoreboard and the coverage collector. This is the sole source of the core's architectural state stream.
*   **Instruction Port Monitor**: Reconstructs fetch transactions from the instruction port handshake, pairing each request address with its response word.
*   **Data Port Monitor**: Reconstructs load and store transactions from the data port handshake, capturing address, direction, byte strobes, and data.

The bus monitors exist to check the core's memory behavior against the architectural stream — that the bus traffic the core actually generated is the traffic the retired instructions claim (§5, check 6). Without them, a core that reports a correct store on RVFI but drives the wrong bytes on the bus would pass.

---

## 5. Scoreboard Checks

The scoreboard consumes two streams: retirement transactions from the RVFI monitor, and golden retirement transactions from the trace adapter. It compares them index by index.

1.  **Retirement Sequencing**: `rvfi_order` starts at zero and increments by exactly one per retirement, with no gaps and no reuse. The two streams are the same length at end of test; a short design stream is a hang, a long one is an over-retirement.
2.  **Program Counter Check**: `rvfi_pc_rdata` matches the golden retirement's address, and `rvfi_pc_wdata` matches the golden model's next address. Checking both directions catches a control transfer that computes the right target but lands on the wrong instruction.
3.  **Instruction Word Check**: `rvfi_insn` matches the golden instruction word. A mismatch here isolates a fetch-path defect before any execution result is examined, which shortens debug considerably.
4.  **Register Write Check**: `rvfi_rd_addr` and `rvfi_rd_wdata` match the golden model's register write. A retirement the golden model records as writing no register must report `rvfi_rd_addr == 0`.
5.  **Memory Access Check**: For each retirement with a nonzero `rvfi_mem_rmask` or `rvfi_mem_wmask`, the address, mask, and data match the golden model's memory access. Loads additionally check `rvfi_mem_rdata` against the memory model's pre-state word.
6.  **Bus / Architecture Consistency Check**: Every data-port transaction observed by the bus monitor corresponds to exactly one retirement reporting a memory access, with matching address, direction, byte lanes, and data — and vice versa. Every fetch response observed corresponds to the `rvfi_insn` of the retirement at that program counter.
7.  **Fault Check**: A retirement with `rvfi_trap` asserted corresponds to a golden-model trap of the same cause at the same instruction, and reports no register or memory effect.
8.  **Termination Check**: The test terminates through a `SIM_EXIT` write with a success code, within the program's instruction budget. A timeout, an unexpected halt, or a nonzero exit code fails the test.

---

## 6. SVA Inventory

All assertions are implemented in a separate bind file and instantiated in `tb_top`. Boundary assertions constrain the memory ports; architectural assertions constrain the retirement port; white-box assertions constrain the core's internals.

### Boundary Protocol Assertions

Applied independently to the instruction and data ports.

**Note on scope:** B1, B2, B3, B5, B6, B8, and B9 constrain signals the core drives and are obligations of the DUT. B4 and the `req_ready` behavior constrain signals the memory model drives, so those double as legality checks on the testbench — a memory model that violates them invalidates every result obtained through it. B7 applies to both directions.

*   **B1 [assert]** `req_valid` remains asserted until `req_ready` is asserted and the handshake completes.
*   **B2 [assert]** The request payload is stable while `req_valid` is high and `req_ready` is low, applied per signal (`addr`; and on the data port `we`, `wstrb`, `wdata`).
*   **B3 [assert]** `req_addr[1:0]` is zero on every accepted request.
*   **B4 [assert]** `rsp_valid` is asserted only in response to a previously accepted request on the same port, and exactly once per accepted request.
*   **B5 [assert]** The outstanding-transaction count on each port is bounded to `[0, 1]`.
*   **B6 [assert]** While `rst_n` is low, `req_valid` is low on both ports, and no `req_valid` rises before the first cycle after reset deassertion.
*   **B7 [assert]** No signal on an active port contains unknown values (X/Z) while its qualifying valid is high.
*   **B8 [assert]** `dmem_req_wstrb` is nonzero whenever `dmem_req_we` is high on an accepted request.
*   **B9 [assert]** No request is issued on either port after `core_halted` asserts.

### Architectural Assertions

Applied to the retirement observation port. These are properties the core owes independently of what the golden model says, and they hold under formal as well as simulation.

*   **A1 [assert]** `rvfi_order` increments by exactly one on each assertion of `rvfi_valid`.
*   **A2 [assert]** `rvfi_pc_rdata[1:0]` is zero on every retirement.
*   **A3 [assert]** `rvfi_pc_wdata` equals `rvfi_pc_rdata + 4` unless the retired instruction is `JAL`, `JALR`, or a taken branch, or the retirement has `rvfi_trap` asserted (MAS §8).
*   **A4 [assert]** `rvfi_rd_addr == 0` implies `rvfi_rd_wdata == 0`.
*   **A5 [assert]** `rvfi_rs1_addr == 0` implies `rvfi_rs1_rdata == 0`, and likewise for `rs2`.
*   **A6 [assert]** `rvfi_rd_addr` is zero for every retired store, branch, and `FENCE`.
*   **A7 [assert]** `rvfi_mem_rmask` and `rvfi_mem_wmask` are both zero for every retirement that is not a load or store, and are never both nonzero on the same retirement.
*   **A8 [assert]** `rvfi_mem_addr[1:0]` is zero whenever either mask is nonzero.
*   **A9 [assert]** A retirement with `rvfi_trap` asserted reports `rvfi_rd_addr == 0` and both memory masks zero.
*   **A10 [assert]** No retirement occurs after a retirement with `rvfi_halt` asserted.
*   **A11 [assert]** No retirement occurs in a cycle in which a request accepted on either port is still awaiting its response. A response arriving in the same cycle satisfies the request, so a load may retire on the cycle its `rsp_valid` asserts.
*   **A12 [assert]** No X/Z on any RVFI field while `rvfi_valid` is high.

### White-Box Design Assertions

*   **W1 [waived — §11]** A register file write targeting index zero never changes the stored value of `x0`, regardless of whether the write-enable presented to the register file is asserted.
*   **W2 [assert]** A read of register index zero returns zero regardless of the contents of the storage array.
*   **W3 [assert]** Exactly one writeback source is selected per retirement — the writeback select is one-hot.
*   **W4 [assert]** The program counter and register file hold their values on every cycle in which no retirement occurs.
*   **W5 [assert]** No data-port request is issued for an instruction that is not a load or a store.
*   **W6 [assert]** No data-port request is issued for an effective address that violates the alignment rules of MAS §7.
*   **W7 [assert]** The program counter equals `RESET_VECTOR` from reset deassertion until the first retirement.
*   **W8 [assert]** The fetch address presented on the instruction port equals the current program counter.
*   **W9 [assert]** Illegal-instruction detection asserts for every instruction word outside the decode table, and only for those words.
*   **W10 [assert]** `core_halted`, once asserted, remains asserted until reset.

### Stimulus Constraints

*   **C1 [constraint]** Generated programs contain only encodings legal under MAS §5, except in tests that deliberately inject illegal words.
*   **C2 [constraint]** Generated loads and stores address only the scratch data region, and are naturally aligned except in tests that deliberately inject misalignment.
*   **C3 [constraint]** Generated branch and jump targets fall within the program text region and are 4-byte aligned except where misaligned fetch is deliberately injected.
*   **C4 [constraint]** Every generated program terminates within a bounded instruction count, and every backward branch is bounded by a counted loop.
*   **C5 [constraint]** Memory `req_ready` deassertion and response latency are randomized per transaction and independently per port, across a range that includes zero wait states and long stalls.
*   **C6 [constraint]** Register operand selection is biased to hit `x0` as each of `rs1`, `rs2`, and `rd`, and to hit the aliasing cases `rd == rs1`, `rd == rs2`, and `rs1 == rs2`.
*   **C7 [constraint]** Immediate fields are biased toward corners: zero, ±1, the maximum positive and minimum negative value of each format, and values that set the sign bit.
*   **C8 [constraint]** Register values are seeded and biased toward arithmetic corners: zero, one, `0x7FFF_FFFF`, `0x8000_0000`, and `0xFFFF_FFFF`.

---

## 7. Formal Verification Plan

`riscv-formal` proves ISA conformance exhaustively within a bounded depth, using the RVFI port already required by MAS §8 as its only interface to the core.

**Harness.** An `rvfi_wrapper.sv` instantiates the core, connects the RVFI port, and abstracts both memory ports so the solver may return arbitrary responses subject to the protocol contract of MAS §6. A `checks.cfg` declares the ISA, the RVFI parameters, and the per-check depths; `genchecks.py` expands it into one SymbiYosys job per check.

**Defines:** `RISCV_FORMAL_ALIGNED_MEM` is set, consistent with the word-aligned bus and the misaligned-access trap policy. `RISCV_FORMAL_ALTOPS` is *not* required, because no multiply or divide instruction is in scope — the substitution exists precisely for the operations model checkers cannot handle, and this core has none.

**Check families:**

| Check | Proves |
|---|---|
| `insn_<name>` | The state transition reported on RVFI matches the ISA definition of that instruction. One check per instruction in MAS §5. This is the bulk of the proof. |
| `pc_fwd` | The next instruction's `rvfi_pc_rdata` equals the previous instruction's `rvfi_pc_wdata` — control flow is continuous. |
| `pc_bwd` | The same property established in the reverse direction, for pairs retired out of order. |
| `reg` | A value read from a register equals the value most recently written to it. This is the check that covers the register-read path the co-simulation scoreboard cannot reach (§3.1). |
| `unique` | No two retirements share an `rvfi_order` index. |
| `causal` | Instructions that depend on one another through a register retire in dependency order. |
| `liveness` | For every retired instruction, the next one is also retired within the bound — the core does not freeze. |
| `cover` | Reachability witnesses for interesting RVFI events. Run first: its results establish the depths the other checks need. |

**Procedure.** Run `cover` first to establish bounds, then bring up a single `insn` check end-to-end before expanding to the full set. Depths start at the minimum that admits a full retirement and increase until each check passes or a counterexample appears. A counterexample is a design defect until proven otherwise and is logged in §13 like any other.

**Stage 2** adds `rvfi_csr_*` channels and the corresponding CSR checks, and requires the trap-related properties to be re-established under trap redirection rather than halt.

---

## 8. Functional Coverage Plan

Coverage is sampled on the retirement observation port, so every coverpoint is defined in terms of architecturally retired instructions rather than internal signals. This makes the coverage model independent of the microarchitecture and reusable without change on the pipelined successor.

### Coverpoints

*   **Instruction**: One bin per instruction in MAS §5. The primary axis.
*   **Instruction Format**: R, I, S, B, U, J.
*   **Branch Outcome**: Taken and not-taken, per branch instruction.
*   **Branch Direction**: Forward and backward displacement.
*   **Jump Target Source**: `JAL` (immediate) and `JALR` (register), including `JALR` with a target whose bit 0 required clearing.
*   **Destination Register**: `rd == x0`, `rd == x1`, and other, per writing instruction.
*   **Operand Aliasing**: `rd == rs1`, `rd == rs2`, `rs1 == rs2`, `rs1 == x0`, `rs2 == x0`, and none of these.
*   **ALU Result Corners**: Zero, all-ones, `0x7FFF_FFFF`, `0x8000_0000`, carry out of the MSB, and signed-overflow boundary crossings.
*   **Shift Amount**: 0, 1, 31, and intermediate, per shift instruction.
*   **Immediate Corners**: Zero, ±1, and the maximum and minimum value of each immediate format.
*   **Load/Store Width**: Byte, halfword, word.
*   **Byte Offset**: Effective-address offset within the word — 0, 1, 2, 3.
*   **Load Extension**: Signed (`LB`, `LH`) and unsigned (`LBU`, `LHU`).
*   **Store Strobe Pattern**: Every `wstrb` value the core can legally generate.
*   **Memory Response Latency**: Zero wait states, 1, 2–4, and greater than 4 cycles — sampled per port.
*   **Request Backpressure**: `req_valid` accepted immediately versus stalled by `req_ready` — sampled per port.
*   **Fault Cause**: Each condition in the MAS §7 fault table.
*   **PC Update Source**: Sequential, taken branch, `JAL`, `JALR`.

### Required Crosses

*   `Instruction` × `Operand Aliasing` — every instruction exercised with `x0` and with its aliasing cases.
*   `Branch Instruction` × `Branch Outcome` × `Branch Direction` — every branch taken and not-taken, in both directions.
*   `Load/Store Width` × `Byte Offset` × `Load Extension` — every legal alignment of every access width, in both extension modes.
*   `Shift Instruction` × `Shift Amount` — including the zero and maximum shift on each of `SLL`/`SRL`/`SRA` and their immediate forms.
*   `Instruction` × `Memory Response Latency` — every instruction retired both with and without an intervening memory stall. This is the cross that proves the stall path corrupts no instruction class, and it is the one a uniform random stream will not close on its own.
*   `ALU Instruction` × `ALU Result Corners` — each arithmetic and comparison instruction driven to its boundary results.

### Closure Target

The must-hit set below is required at 100%. Overall functional coverage must reach ≥ 95%, with written waivers (§11) for intentionally unreachable bins.

*   Every instruction in MAS §5 retired at least once.
*   Every branch instruction, both outcomes, both directions.
*   Every load and store width at every legal byte offset, and every signed/unsigned load extension.
*   Every legally generatable `wstrb` pattern.
*   `rd == x0` for at least one instruction of each writing format.
*   Every operand-aliasing case for at least one R-type and one I-type instruction.
*   Shift amounts 0 and 31 on every shift instruction.
*   Both zero-wait-state and stalled retirements for every instruction format.
*   Every fault cause in the MAS §7 table.
*   All four PC update sources.

---

## 9. Constrained-Random Strategy

Stimulus for a processor is generated *programs*, and coverage is a property of the instruction streams those programs contain. Two independent randomization axes are driven:

**Program content.** The Instruction Stream Generator emits randomized legal RV32I assembly, assembled and linked by the RISC-V GCC toolchain into an ELF the loader consumes. Generation is constrained by C1–C4 so every program is legal, memory-safe, and terminating — an unterminated or wild-jumping program is a generator defect, not a core defect, and the constraints exist to keep those out of the regression. Operand selection, immediates, and seeded register values are biased per C6–C8, because the interesting states of an ALU are its boundaries and a uniform random stream reaches them rarely.

**Memory timing.** The Memory Timing Agent randomizes wait states and response latency per transaction and independently per port (C5). This axis is orthogonal to program content by construction: every program in the suite can be replayed under randomized timing, and MAS §7 requires the results to be identical. That equality is itself a check — it is what proves stalling is architecturally invisible.

The two axes cross. `test_memory_stall` (§10) is the directed suite replayed under randomized timing; `test_random_program` runs generated programs under randomized timing throughout.

---

## 10. Test Case Inventory

*   **`test_smoke`**: A short hand-written assembly program executing one instruction of each format, with zero-wait-state memory. The bring-up target: the first test to pass, and the fastest failure signal in regression.
*   **`test_directed_isa`**: Hand-written directed programs per instruction group, targeting the corners named in the MAS — `x0` as source and destination, `rd == rs1` aliasing, shift amounts of 0 and 31, `SLT`/`SLTU` signed-versus-unsigned boundary pairs, `SRA` sign propagation, `ADD` overflow at `0x7FFF_FFFF`, and `AUIPC`/`JAL` relative-address computation.
*   **`test_control_flow`**: Every branch instruction in both outcomes, forward and backward; `JAL` and `JALR` across the reachable displacement range; `JALR` with `rd == rs1`; branch targets at region boundaries; `JALR` bit-0 clearing.
*   **`test_memory_access`**: Load and store width (`B`/`H`/`W`) crossed with every legal byte offset within the word, crossed with signed and unsigned load extension. Includes store-then-load round trips through every byte lane to prove `wstrb` masking preserves adjacent bytes.
*   **`test_fault`**: Each fault condition of MAS §7 injected individually — illegal instruction words including all-zero, misaligned load, misaligned store, misaligned fetch via `JALR`, access fault via a memory-model error response, and `ECALL`/`EBREAK`. Each is checked for the correct halt behavior and correct RVFI reporting.
*   **`test_memory_stall`**: The directed suite above replayed under randomized memory timing (C5), with results required to be bit-identical to the zero-wait-state run.
*   **`test_random_program`**: Generated random programs — target 500 programs of roughly 2,000 instructions each — every one diffed against the golden model over its full execution, under randomized memory timing.
*   **`test_compiled_c`**: Bare-metal C programs compiled for `-march=rv32i -mabi=ilp32`, exercising the core against real compiler output: function calls and the stack, struct and array access, loops, and integer arithmetic that the compiler lowers into shift-and-add sequences. Console output through `SIM_PUTC`.
*   **`test_riscv_tests`** *(Stage 2)*: The upstream `riscv-tests` `rv32ui-p-*` suite, executed unmodified. Requires the CSR and trap support of MAS §11, including the trap-on-unimplemented-CSR behavior its reset sequence depends on (MAS §11.4).

---

## 11. Waivers

This section documents coverage and assertion gaps that are structurally unreachable by the testbench architecture, rather than merely rare. Each entry records why the gap cannot be closed by stimulus and what discharges it instead — a formal proof where one exists.

| ID | Coverage Gap | Unreachable Reason | Disposition |
|---|---|---|---|
| **WAIVER - 01** | `regs[0]` write-immunity proof (Property: `W1`) | Sole write path is a single unconditional guard (`if (we3 && a3 != 5'b0) regs[a3] <= wd3;`), and `regs[0]` is unobservable externally since the read mux already forces zero at address 0 regardless of array contents. | Closed by RTL inspection, not a dedicated assertion. |
| **WAIVER - 02** | `ALU Instruction × ALU Result Corners` cross covers `add`/`sub`/`addi` only | All ALU ops share one combinational mux with no per-instruction corner logic, and `carry`/`overflow` are only architecturally meaningful for `ADD`/`SUB`/`ADDI`. Shifts are covered separately by `cx_shift_instr_amt`. | Closed by `cp_alu_result`'s existing uncrossed sampling across all ALU ops. |

---

## 12. Sign-off / Exit Criteria

Verification is complete and ready for release when:

*   **Zero Architectural Mismatches**: The scoreboard reports zero divergences from the golden model across the full regression, on every check in §5.
*   **Zero Protocol Violations**: No boundary, architectural, or white-box assertion failure across the regression.
*   **Functional Coverage**: 100% of the must-hit coverpoints and crosses (§8) are reached or covered by an approved waiver (§11), and overall functional coverage is ≥ 95%.
*   **Instruction Completeness**: Every instruction in MAS §5 is retired at least once in the regression and appears in the coverage report. An instruction that is implemented but never executed is not verified.
*   **Program Suite**: The full directed suite, the compiled C programs, and the random program regression all terminate with a success exit code.
*   **Stall Invariance**: The directed suite produces bit-identical architectural results under zero-wait-state and randomized memory timing.
*   **Formal Proofs**: All `riscv-formal` checks in §7 pass at their configured depths, or are explicitly waived with a documented reason. *Time-boxed and non-blocking per §1: a formal check not yet passing is recorded as an open item, not a failed sign-off, provided the co-simulation criteria above are met.*
*   **Regression Status**: The regression compiles and completes cleanly without warnings.
*   **Bug-Hunt Log**: Populated, with each entry root-caused and resolved (§13).

---

## 13. Bug-Hunt Log

This log is a living artifact, populated during bring-up and regression. Each entry records a defect and how it was caught, with priority given to defects found by random program generation or formal analysis that the directed suite missed — those are the entries that demonstrate the verification environment earned its cost.

| ID & Type | Observed Symptom | Root Cause & Resolution | Affected File |
|---|---|---|---|
| **BUG-01 [RTL]** | Under `RANDOMIZE=1`, `W9` (illegal-instr mismatch) and `B1_IMEM` (valid dropped before ready) failed intermittently. | Controller, RVFI, and datapath decoded `imem_rsp_rdata` combinationally with no gate on `imem_rsp_valid`, so a pending-but-unanswered fetch could present stale/garbage data as the current instruction, occasionally decoding as illegal and halting the core mid-request. Added `instr_word`, a live-bus/held-register mux gated on `imem_rsp_valid`, and routed all consumers through it. | `rtl/rv32i_core.sv`, `dv/sva/whitebox_sva.sv` |
