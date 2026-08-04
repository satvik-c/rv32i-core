# RV32I Core Microarchitecture Specification (MAS)

This document defines the functional and architectural behavior of the single-cycle RV32I core. It specifies the instruction scope, the memory interface contract, the retirement observation port, and the exception policy. Instruction semantics are not restated here; they are defined by the RISC-V Unprivileged ISA specification (Volume I, RV32I base integer instruction set, version 2.1).

![RV32I Core Block Diagram](./core_microarch.png)

---

## 1. Specification Staging

The specification is delivered in two stages. Stage 1 is the complete, self-sufficient scope: a core built to Stage 1 executes RV32I programs and is verifiable end-to-end. Stage 2 is a bounded scope increment layered on top of it.

| Stage | Scope | Rationale |
|---|---|---|
| **Stage 1** | RV32I base integer instruction set. No CSRs. No trap handling — architectural faults halt the core. | The complete base ISA, with the smallest surface that still permits full ISA-conformance verification. |
| **Stage 2** | Adds Zicsr, the machine-mode CSR subset, and trap redirection (§11). | Required to execute the upstream `riscv-tests` suite unmodified, and to give SoC firmware an exception path. |

Sections 2 through 10 define Stage 1. Section 11 defines the Stage 2 delta. Unless a section is explicitly marked, its contents apply to both stages.

---

## 2. Interface Contract

The core exposes four logical interfaces:

| Logical Interface | Description / Contract | Associated Information |
|---|---|---|
| **System Controls** | System clock and synchronous reset input. | Single clock domain; active-low reset. |
| **Instruction Memory Port** | Decoupled request-response port for instruction fetch. | Read-only, word-aligned, single-outstanding. |
| **Data Memory Port** | Decoupled request-response port for load and store access. | Read/write, word-aligned with byte-lane strobes, single-outstanding. |
| **Retirement Observation Port (RVFI)** | Output-only port reporting the architectural effect of each retired instruction. | Not part of the functional datapath; see §8. |

**System Parameters:**
*   **`XLEN`**: Fixed at 32 bits. Not configurable.
*   **`RESET_VECTOR`**: Address of the first instruction fetched after reset. Default `32'h8000_0000`. Configurable at elaboration.
*   **`HART_ID`**: Hardware thread identifier. Default `0`. Unused in Stage 1; reported through `mhartid` in Stage 2.

**Top-Level Signal Contract**

| Signal | Width | Direction | Description |
|---|---|---|---|
| `clk` | 1 | Input | System clock. |
| `rst_n` | 1 | Input | Active-low synchronous reset. |
| `imem_req_valid` | 1 | Output | Instruction fetch request valid. |
| `imem_req_ready` | 1 | Input | Instruction fetch request accepted. |
| `imem_req_addr` | 32 | Output | Instruction fetch address. Bits `[1:0]` are always zero. |
| `imem_rsp_valid` | 1 | Input | Instruction fetch response valid. |
| `imem_rsp_rdata` | 32 | Input | Fetched instruction word. |
| `imem_rsp_error` | 1 | Input | Fetch access fault indication. |
| `dmem_req_valid` | 1 | Output | Data access request valid. |
| `dmem_req_ready` | 1 | Input | Data access request accepted. |
| `dmem_req_addr` | 32 | Output | Data access address. Bits `[1:0]` are always zero. |
| `dmem_req_we` | 1 | Output | Data access direction: 1 = write, 0 = read. |
| `dmem_req_wstrb` | 4 | Output | Write byte-lane strobes. Valid only when `dmem_req_we` is high. |
| `dmem_req_wdata` | 32 | Output | Write data, positioned in its addressed byte lanes. |
| `dmem_rsp_valid` | 1 | Input | Data access response valid. |
| `dmem_rsp_rdata` | 32 | Input | Read data word. Valid only for read requests. |
| `dmem_rsp_error` | 1 | Input | Data access fault indication. |
| `core_halted` | 1 | Output | Asserted and held once the core has ceased retiring instructions (§7). |
| `rvfi_*` | — | Output | Retirement observation port. Enumerated in §8. |

Response channels carry no backpressure: the core accepts `imem_rsp_valid` and `dmem_rsp_valid` unconditionally in the cycle they are asserted.

---

## 3. Clock and Reset Semantics

*   **Single Clock Domain**: The entire core operates on one clock. No clock domain crossing logic, clock gating, or derived clocks are implemented.
*   **Reset**: Synchronous, active-low. While `rst_n` is asserted low, no request valid is driven on either memory port and no instruction retires.
*   **Reset State**: On reset deassertion, the program counter holds `RESET_VECTOR` and `core_halted` is low. The architectural register file is not reset; `x0` reads as zero structurally, and `x1`–`x31` hold indeterminate values until written. Programs must not read an architectural register before writing it.
*   **First Fetch**: The first instruction fetch request is issued no earlier than the first clock edge after `rst_n` deasserts.

---

## 4. Architectural State

The core's architecturally visible state is exactly:

| State | Width | Description |
|---|---|---|
| **Program Counter** | 32 | Address of the instruction currently being executed. Always a multiple of 4 (§7). |
| **Integer Register File** | 32 × 32 | `x0`–`x31`. `x0` reads as zero and discards all writes. Two read ports and one write port are required by the base ISA. |

Memory is external to the core and is not part of its state. Stage 2 adds the CSR file (§11).

**Register File Rules:**
*   A read of `x0` returns zero irrespective of any prior write.
*   A write with destination `x0` has no effect on any subsequent read.
*   An instruction that both reads and writes the same register observes the pre-instruction value on its read port.

---

## 5. Instruction Scope

Stage 1 implements the complete RV32I base integer instruction set: 37 computational, control-transfer, and memory instructions, plus `FENCE`, `ECALL`, and `EBREAK`.

| Format | Instructions |
|---|---|
| **R-type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` |
| **I-type (ALU)** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` |
| **I-type (load)** | `LB`, `LH`, `LW`, `LBU`, `LHU` |
| **I-type (jump)** | `JALR` |
| **S-type** | `SB`, `SH`, `SW` |
| **B-type** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| **U-type** | `LUI`, `AUIPC` |
| **J-type** | `JAL` |
| **System / misc** | `FENCE`, `ECALL`, `EBREAK` |

**Encoding and semantics** are those of the RISC-V Unprivileged ISA specification. This document does not restate operand extraction, immediate construction, or arithmetic definitions; the ISA specification is the normative source, and any divergence from it is a defect.

**Instruction-specific policy:**
*   **`FENCE`**: Decoded as a legal instruction and retired with no architectural effect. The core issues at most one memory transaction at a time and has no store buffer or cache, so no ordering enforcement is required.
*   **`ECALL` / `EBREAK`** *(Stage 1)*: Decoded as legal instructions. Both halt the core per §7. Stage 2 redirects them to the trap vector instead (§11).
*   **Shift instructions**: Shift amounts are taken from the low 5 bits of the operand. `SLLI`, `SRLI`, and `SRAI` encodings with a nonzero bit 25 are illegal (§7).
*   **`AUIPC` and `JAL`**: Compute relative to the address of the instruction itself, not the address of the next instruction.

---

## 6. Memory Interface Protocol

Both memory ports use the same decoupled request-response protocol. The instruction port omits the write signals.

**Handshake Rules:**
1.  A request is presented by asserting `req_valid` and is transferred on the first cycle where `req_valid` and `req_ready` are both high.
2.  Once `req_valid` is asserted it remains asserted until the request is accepted. The request payload (`addr`, `we`, `wstrb`, `wdata`) is stable across that interval.
3.  `req_ready` may be asserted before, during, or after `req_valid`, and may be withdrawn in any cycle in which no transfer occurs.
4.  Each port carries at most one outstanding request. No new request is presented on a port until the response to the previous request on that port has been received.
5.  `rsp_valid` is asserted for exactly one cycle per accepted request. There is no response backpressure.
6.  Responses on the two ports are independent and may be returned in any relative order.
7.  A port's request latency is unbounded from the core's perspective: it stalls indefinitely and correctly for any `req_ready` and `rsp_valid` timing that obeys these rules.

**Addressing and Byte Lanes:**
*   All bus addresses are word-aligned. `req_addr[1:0]` is always zero.
*   For stores, the core positions the store data into the byte lanes selected by the effective address and asserts the corresponding `wstrb` bits: `SW` asserts `4'b1111`; `SH` asserts `4'b0011` or `4'b1100`; `SB` asserts a single lane. Lanes with an unasserted strobe must not be modified by the memory.
*   For loads, the memory returns the full addressed word. The core extracts the addressed byte or halfword and applies sign extension (`LB`, `LH`) or zero extension (`LBU`, `LHU`).
*   `wstrb` is meaningful only for writes. For reads, `dmem_req_we` is low and `wstrb` is ignored.

**Error Responses:** `imem_rsp_error` and `dmem_rsp_error` indicate an access fault reported by the memory system. In Stage 1 either halts the core per §7. Stage 2 converts them to traps (§11).

---

## 7. Execution, Retirement, and Fault Policy

**Execution Model:**
*   The core issues one instruction fetch, evaluates the fetched instruction, issues at most one data access if the instruction is a load or store, and retires. No instruction is fetched while a previous instruction is still executing.
*   While any memory response is outstanding, the core makes no change to the program counter or the register file. Stalling is architecturally invisible: a program's results do not depend on the wait states the memory inserts.
*   Architectural state is updated atomically at retirement. A partially applied instruction is never observable.
*   At most one instruction retires per clock cycle.

**Program Counter Rules:**
*   The program counter is a multiple of 4 at every point in execution.
*   The next program counter is the current program counter plus 4, except after a taken branch, `JAL`, or `JALR`, where it is the computed target.
*   `JALR` clears bit 0 of its computed target, per the ISA specification. It does not clear bit 1; a `JALR` target with bit 1 set is a misaligned instruction fetch and faults per the table below.

**Fault Policy (Stage 1).** Stage 1 has no trap handler. Each condition below terminates execution: the core reports the faulting instruction on the retirement port with `rvfi_trap` and `rvfi_halt` asserted, asserts `core_halted`, and issues no further requests on either port. `core_halted` is held until reset.

| Condition | Detected When |
|---|---|
| **Illegal instruction** | The fetched word matches no encoding in §5, including reserved and all-zero words. |
| **Misaligned instruction fetch** | The next program counter is not a multiple of 4. Reported against the control-transfer instruction that produced it, not the target. |
| **Misaligned load** | A `LH`/`LHU` effective address is odd, or a `LW` effective address is not a multiple of 4. |
| **Misaligned store** | A `SH` effective address is odd, or a `SW` effective address is not a multiple of 4. |
| **Access fault** | The memory system asserts `imem_rsp_error` or `dmem_rsp_error`. |
| **Environment call / breakpoint** | `ECALL` or `EBREAK` is retired. |

A misaligned load or store is detected before any bus activity: no data-port request is issued for a faulting access.

---

## 8. Retirement Observation Port (RVFI)

The core exposes a RISC-V Formal Interface port reporting the architectural effect of each retired instruction. The port is output-only and has no functional role: removing it changes no architectural behavior. It exists so that one observation mechanism serves both consumers of this core's verification — the simulation scoreboard that diffs against a golden ISA simulator, and the `riscv-formal` property set that proves ISA conformance exhaustively.

The port is instantiated with `NRET = 1`, `XLEN = 32`, `ILEN = 32`.

| Signal | Width | Description |
|---|---|---|
| `rvfi_valid` | 1 | Asserted for one cycle when an instruction retires. All fields below are meaningful only in that cycle. |
| `rvfi_order` | 64 | Retirement index. Starts at zero, increments by one per retirement, with no gaps or reuse. |
| `rvfi_insn` | 32 | The retired instruction word. |
| `rvfi_trap` | 1 | The instruction raised one of the conditions in §7. |
| `rvfi_halt` | 1 | The instruction is the last the core retires before halting. |
| `rvfi_intr` | 1 | The instruction is the first of a trap handler. Tied low in Stage 1. |
| `rvfi_mode` | 2 | Current privilege level. Tied to `2'd3` (machine mode). |
| `rvfi_ixl` | 2 | Effective XLEN encoding. Tied to `2'd1` (32-bit). |
| `rvfi_rs1_addr` | 5 | Decoded `rs1` index, or zero when the instruction reads no `rs1`. |
| `rvfi_rs2_addr` | 5 | Decoded `rs2` index, or zero when the instruction reads no `rs2`. |
| `rvfi_rs1_rdata` | 32 | Pre-state value of the `rs1` register. Zero when `rvfi_rs1_addr` is zero. |
| `rvfi_rs2_rdata` | 32 | Pre-state value of the `rs2` register. Zero when `rvfi_rs2_addr` is zero. |
| `rvfi_rd_addr` | 5 | Decoded `rd` index, or zero when the instruction writes no register. |
| `rvfi_rd_wdata` | 32 | Post-state value of the `rd` register. Zero when `rvfi_rd_addr` is zero. |
| `rvfi_pc_rdata` | 32 | Address of the retired instruction. |
| `rvfi_pc_wdata` | 32 | Address of the next instruction to execute. |
| `rvfi_mem_addr` | 32 | Word-aligned address of the memory access, when one occurred. |
| `rvfi_mem_rmask` | 4 | Byte lanes of `rvfi_mem_rdata` holding valid read data. Zero for non-loads. |
| `rvfi_mem_wmask` | 4 | Byte lanes of `rvfi_mem_wdata` written. Zero for non-stores. |
| `rvfi_mem_rdata` | 32 | Pre-state word at `rvfi_mem_addr`. |
| `rvfi_mem_wdata` | 32 | Post-state word at `rvfi_mem_addr`. |

**Conventions:**
*   `RISCV_FORMAL_ALIGNED_MEM` applies: `rvfi_mem_addr` is word-aligned, and the masks identify the accessed lanes within that word. This matches the bus contract in §6.
*   `rvfi_rd_addr` is zero — not merely `rvfi_rd_wdata` — for any instruction that writes no register, including stores and branches.
*   For an instruction retired with `rvfi_trap` set, the register and memory channels report no effect.
*   In Stage 1, an instruction retired with `rvfi_trap` set reports `rvfi_pc_wdata` equal to `rvfi_pc_rdata`: execution does not advance, because there is no handler to advance to. In Stage 2 it reports the trap vector address instead.

---

## 9. Memory Map

The core imposes no memory map: it presents whatever address a program computes. The map below is the contract between programs, the linker script, and the memory model that backs the two ports.

| Region | Base | Size | Contents |
|---|---|---|---|
| **Program text** | `0x8000_0000` | Implementation-defined | Instructions. Contains `RESET_VECTOR`. Served by the instruction port. |
| **Program data** | Follows text | Implementation-defined | Initialized data, `.bss`, and stack. Served by the data port. |
| **Simulation control** | `0x1000_0000` | 16 B | Write-only registers, below. |

**Simulation control registers.** These are not part of the core. They exist in the memory model so that a program running on the core can terminate the simulation and emit console output without requiring any interrupt or CSR mechanism.

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x0` | `SIM_EXIT` | WO | Writing a value with bit `[0]` set terminates the simulation. Bits `[31:1]` carry the exit code; zero indicates success. |
| `0x4` | `SIM_EXIT_HI` | WO | Upper word of the 64-bit termination value. Writes are accepted and ignored. |
| `0x8` | `SIM_PUTC` | WO | Bits `[7:0]` are appended to the simulation console log. Provides a `putchar` path for compiled C programs. |

`SIM_EXIT` mirrors the `tohost` convention of the upstream `riscv-tests` suite, so those binaries link `tohost` to this address unmodified in Stage 2. `SIM_EXIT_HI` exists because that suite's termination sequence writes a 64-bit `tohost` as two word stores (`tohost` and `tohost+4`) even on RV32; the upper word must be absorbed rather than aliased onto another register.

The base address `0x8000_0000` matches the default RAM base of the reference ISA simulator and the default link address of `riscv-tests`, which keeps the co-simulation flow free of address translation.

---

## 10. Architectural Scope and Limits (Stage 1)

The design scope is bounded by the following simplifications. Each is a deliberate exclusion, not an omission.

*   **Single-Issue, In-Order, Non-Speculative**: One instruction is in flight at a time. There is no pipelining, branch prediction, or speculative fetch. Pipelining is the scope of the successor project.
*   **No Privilege Modes**: Execution is unconditionally in machine mode. No user or supervisor mode, and no privilege transitions.
*   **No Interrupts**: There is no interrupt input and no asynchronous control transfer. Every control transfer originates from a retired instruction.
*   **No Caches or Memory Management**: Both ports address physical memory directly. No cache, TLB, or address translation.
*   **No Multiply or Divide**: The M extension is out of scope. `MUL`/`DIV`/`REM` encodings are illegal instructions.
*   **No Compressed Instructions**: The C extension is out of scope. All instructions are 32 bits and all fetch addresses are word-aligned.
*   **No Atomics or Floating Point**: The A, F, and D extensions are out of scope.
*   **No Misaligned Access Support**: Misaligned loads, stores, and fetches fault (§7). They are not emulated in hardware.
*   **No Performance Counters**: Stage 1 has no CSRs at all, therefore no `cycle`, `time`, or `instret` counters.

---

## 11. Stage 2 Scope Increment: Zicsr and Machine-Mode Traps

Stage 2 replaces the halt-on-fault policy of §7 with trap redirection, and adds the CSR access instructions. It is additive: no Stage 1 instruction changes behavior, no top-level signal changes meaning, and the memory interface contract of §6 is unchanged.

### 11.1 Added Instructions

| Format | Instructions |
|---|---|
| **Zicsr** | `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI` |
| **Trap return** | `MRET` |

Read-side effects and the write-suppression rules for `CSRRS`/`CSRRC` with `rs1 = x0`, and `CSRRW` with `rd = x0`, are those of the ISA specification.

### 11.2 Added Architectural State

| CSR | Address | Description |
|---|---|---|
| `mstatus` | `0x300` | Global interrupt enable and previous-state fields. Only `MIE` and `MPIE` are implemented; `MPP` reads as machine mode. |
| `misa` | `0x301` | Reports `XLEN = 32` and the `I` extension. Writes are ignored. |
| `mtvec` | `0x305` | Trap vector base address. Direct mode only; vectored mode is not implemented. |
| `mscratch` | `0x340` | Scratch register for trap handlers. No hardware behavior. |
| `mepc` | `0x341` | Address of the instruction that caused the trap. Bits `[1:0]` read as zero. |
| `mcause` | `0x342` | Trap cause code. |
| `mtval` | `0x343` | Trap value: the faulting address for misaligned and access faults, the instruction word for illegal instructions, zero otherwise. |
| `mhartid` | `0xF14` | Reads `HART_ID`. Read-only. |

An access to any CSR address not listed above, or a write to a read-only CSR, is an illegal instruction — and therefore a trap, not a halt. This is load-bearing, not incidental: see §11.4.

### 11.3 Trap Behavior

Each condition in the §7 fault table becomes a trap instead of a halt. On a trap the core writes `mepc`, `mcause`, and `mtval`, updates `mstatus`, and redirects the program counter to `mtvec`. `MRET` restores `mstatus` and redirects the program counter to `mepc`. Cause codes follow the machine-mode encoding of the RISC-V Privileged specification:

| Condition | `mcause` |
|---|---|
| Instruction address misaligned | 0 |
| Instruction access fault | 1 |
| Illegal instruction | 2 |
| Breakpoint (`EBREAK`) | 3 |
| Load address misaligned | 4 |
| Load access fault | 5 |
| Store address misaligned | 6 |
| Store access fault | 7 |
| Environment call from M-mode (`ECALL`) | 11 |

`core_halted` and `rvfi_halt` are no longer asserted for these conditions. `rvfi_trap` remains asserted on the faulting instruction, and `rvfi_intr` is asserted on the first instruction of the handler. The `rvfi_csr_*` channels are added for each CSR above, with `RISCV_FORMAL_CSR_<NAME>` defined accordingly.

### 11.4 Sufficiency for the `riscv-tests` Suite

The CSR subset in §11.2 is exactly what the upstream `riscv-tests` `rv32ui-p-*` binaries require, and no more. Their reset sequence uses `mhartid`, `mtvec`, `mstatus`, `mepc`, and `MRET` to enter the test body, and its trap handler reads `mcause`. The `stvec` and `medeleg` writes in that sequence are guarded by a branch on a weak `stvec_handler` symbol, which is null in the integer test set, so they are never executed.

The sequence also writes `satp`, `pmpaddr0`, `pmpcfg0`, `mie`, `medeleg`, and `mideleg` — none of which are implemented here. Those writes are survivable only because each is immediately preceded by a `mtvec` write pointing at the following instruction, so an illegal-instruction trap skips over the unimplemented access and execution continues. That construction is why §11.2 requires an unimplemented CSR access to **trap** rather than halt: a core that halts on an unknown CSR write terminates in the first few instructions of every one of these tests, before reaching any test body.

Termination is the `unimp` instruction at the end of each test, which traps and routes to a handler that writes the result to `tohost`, mapped to `SIM_EXIT` (§9).
