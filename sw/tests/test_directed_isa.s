.section .text.init
.globl _start

# test_directed_isa: every R-type and I-type ALU op, LUI/AUIPC/JAL, plus the
# corners named in MAS/vPlan: x0 as src/dst, rd==rs1/rd==rs2/rs1==rs2/rs1==x0/
# rs2==x0 aliasing, shift amounts 0 and 31, SLT/SLTU and SLTI/SLTIU signed-vs-
# unsigned boundary pairs, SRA sign propagation, ADD overflow at 0x7FFFFFFF,
# and I-type immediate corners (0, +-1, max/min). Correctness is verified by
# the spike co-simulation scoreboard; this file only needs to hit the bins.

_start:
    # ---- R-type: one of each, plain case ----
    addi x1, x0, 5
    addi x2, x0, 3
    add  x3, x1, x2          # ADD
    sub  x4, x1, x2          # SUB
    xor  x5, x1, x2          # XOR
    or   x6, x1, x2          # OR
    and  x7, x1, x2          # AND

    # ---- ADD signed-overflow corner (0x7FFFFFFF + 1) ----
    li   x8, 0x7FFFFFFF
    addi x9, x0, 1
    add  x10, x8, x9         # overflows to 0x80000000

    # ---- SLT/SLTU signed-vs-unsigned boundary pair (same operands) ----
    li   x11, 0x80000000     # signed: most-negative; unsigned: huge
    addi x12, x0, 1
    slt  x13, x11, x12       # signed: negative < 1  -> 1
    sltu x14, x11, x12       # unsigned: huge < 1    -> 0

    # ---- SRA sign propagation vs SRL (same operand, shift amt 31 via reg) ----
    li   x15, 0x80000000
    addi x16, x0, 31
    sll  x17, x9, x16        # SLL by 31 -> 0x80000000
    srl  x18, x15, x16       # SRL by 31 -> 0x00000001 (logical)
    sra  x19, x15, x16       # SRA by 31 -> 0xFFFFFFFF (sign-extends)

    # ---- R-type shift amount 0 corner ----
    addi x20, x0, 0
    sll  x21, x9, x20        # SLL by 0 -> unchanged
    srl  x22, x15, x20       # SRL by 0 -> unchanged
    sra  x23, x15, x20       # SRA by 0 -> unchanged

    # ---- I-type ALU: one of each ----
    addi x24, x1, 10         # ADDI
    slti x25, x11, 0         # SLTI  (signed: 0x80000000 < 0 -> 1)
    sltiu x26, x11, 0        # SLTIU (unsigned: huge < 0 -> 0)  -- signed/unsigned pair
    xori x27, x1, -1
    ori  x28, x2, 4
    andi x29, x1, 3

    # ---- I-type shift, immediate amounts 0 and 31 ----
    slli x30, x9, 31
    srli x31, x15, 31
    srai x8,  x15, 31
    slli x9,  x9, 0
    srli x10, x15, 0
    srai x11, x15, 0

    # ---- I-type immediate corners: 0, +1, -1, max(2047), min(-2048) ----
    addi x12, x1, 0
    addi x13, x1, 1
    addi x14, x1, -1
    addi x15, x1, 2047
    addi x16, x1, -2048

    # ---- rd == x0 (write discarded) ----
    add  x0, x1, x2
    addi x0, x1, 5

    # ---- rd == rs1 / rd == rs2 / rs1 == rs2 aliasing (R-type) ----
    addi x17, x0, 9
    addi x18, x0, 4
    sub  x17, x17, x18       # rd == rs1
    addi x17, x0, 9
    addi x18, x0, 4
    sub  x18, x17, x18       # rd == rs2
    and  x19, x17, x17       # rs1 == rs2

    # ---- rs1 == x0 / rs2 == x0 ----
    addi x20, x0, 7          # rs1 == x0 (I-type)
    add  x21, x1, x0         # rs2 == x0 (R-type)

    # ---- I-type aliasing: rd == rs1, rs1 == x0 ----
    addi x22, x0, 3
    addi x22, x22, 1         # rd == rs1 (I-type)

    # ---- U-type / J-type ----
    lui  x23, 0x12345        # LUI
    auipc x24, 1             # AUIPC (relative-address computation)
    jal  x25, jal_target     # JAL, rd != x0, relative-address computation
    addi x26, x0, -1         # skipped
jal_target:
    addi x27, x0, 1

    # ---- FENCE: legal, no architectural effect ----
    fence

    # ---- SIM_EXIT ----
    li   t0, 0x10000000
    addi a0, x0, 1
    sw   a0, 0(t0)
    sw   zero, 4(t0)
done:
    j done
