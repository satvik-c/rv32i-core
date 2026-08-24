.section .text.init
.globl _start

# test_control_flow: every branch instruction, taken and not-taken, forward
# and backward (the full Branch Instruction x Outcome x Direction cross from
# vPlan Section 8); JAL forward and backward; JALR basic, bit-0 clearing, and
# rd==rs1. Correctness is verified by the spike co-simulation scoreboard.

_start:
    # ================= BEQ =================
    addi x1, x0, 5
    addi x2, x0, 5
    beq  x1, x2, beq_f_t
    addi x9, x0, -1
beq_f_t:
    addi x10, x0, 1

    addi x1, x0, 5
    addi x2, x0, 6
    beq  x1, x2, beq_f_nt_bad
    addi x11, x0, 1
beq_f_nt_bad:
    addi x12, x0, 2

    j beq_b_skip
beq_b_target:
    addi x13, x0, 3
    j beq_b_done
beq_b_skip:
    addi x1, x0, 7
    addi x2, x0, 7
    beq  x1, x2, beq_b_target
    addi x14, x0, -1
beq_b_done:

beq_b_nt_target:
    addi x15, x0, -1
    addi x1, x0, 7
    addi x2, x0, 8
    beq  x1, x2, beq_b_nt_target
    addi x16, x0, 1

    # ================= BNE =================
    addi x1, x0, 5
    addi x2, x0, 6
    bne  x1, x2, bne_f_t
    addi x17, x0, -1
bne_f_t:
    addi x18, x0, 1

    addi x1, x0, 5
    addi x2, x0, 5
    bne  x1, x2, bne_f_nt_bad
    addi x19, x0, 1
bne_f_nt_bad:
    addi x20, x0, 2

    j bne_b_skip
bne_b_target:
    addi x21, x0, 3
    j bne_b_done
bne_b_skip:
    addi x1, x0, 7
    addi x2, x0, 8
    bne  x1, x2, bne_b_target
    addi x22, x0, -1
bne_b_done:

bne_b_nt_target:
    addi x23, x0, -1
    addi x1, x0, 7
    addi x2, x0, 7
    bne  x1, x2, bne_b_nt_target
    addi x24, x0, 1

    # ================= BLT (signed) =================
    addi x1, x0, -1
    addi x2, x0, 1
    blt  x1, x2, blt_f_t
    addi x25, x0, -1
blt_f_t:
    addi x26, x0, 1

    addi x1, x0, 1
    addi x2, x0, -1
    blt  x1, x2, blt_f_nt_bad
    addi x27, x0, 1
blt_f_nt_bad:
    addi x28, x0, 2

    j blt_b_skip
blt_b_target:
    addi x29, x0, 3
    j blt_b_done
blt_b_skip:
    addi x1, x0, -5
    addi x2, x0, 0
    blt  x1, x2, blt_b_target
    addi x30, x0, -1
blt_b_done:

blt_b_nt_target:
    addi x31, x0, -1
    addi x1, x0, 0
    addi x2, x0, -5
    blt  x1, x2, blt_b_nt_target
    addi x9, x0, 1

    # ================= BGE (signed) =================
    addi x1, x0, 1
    addi x2, x0, -1
    bge  x1, x2, bge_f_t
    addi x10, x0, -1
bge_f_t:
    addi x11, x0, 1

    addi x1, x0, -1
    addi x2, x0, 1
    bge  x1, x2, bge_f_nt_bad
    addi x12, x0, 1
bge_f_nt_bad:
    addi x13, x0, 2

    j bge_b_skip
bge_b_target:
    addi x14, x0, 3
    j bge_b_done
bge_b_skip:
    addi x1, x0, 0
    addi x2, x0, -5
    bge  x1, x2, bge_b_target
    addi x15, x0, -1
bge_b_done:

bge_b_nt_target:
    addi x16, x0, -1
    addi x1, x0, -5
    addi x2, x0, 0
    bge  x1, x2, bge_b_nt_target
    addi x17, x0, 1

    # ================= BLTU (unsigned) =================
    addi x1, x0, 1
    li   x2, 0x80000000
    bltu x1, x2, bltu_f_t
    addi x18, x0, -1
bltu_f_t:
    addi x19, x0, 1

    li   x1, 0x80000000
    addi x2, x0, 1
    bltu x1, x2, bltu_f_nt_bad
    addi x20, x0, 1
bltu_f_nt_bad:
    addi x21, x0, 2

    j bltu_b_skip
bltu_b_target:
    addi x22, x0, 3
    j bltu_b_done
bltu_b_skip:
    addi x1, x0, 1
    li   x2, 0xFFFFFFFF
    bltu x1, x2, bltu_b_target
    addi x23, x0, -1
bltu_b_done:

bltu_b_nt_target:
    addi x24, x0, -1
    li   x1, 0xFFFFFFFF
    addi x2, x0, 1
    bltu x1, x2, bltu_b_nt_target
    addi x25, x0, 1

    # ================= BGEU (unsigned) =================
    li   x1, 0x80000000
    addi x2, x0, 1
    bgeu x1, x2, bgeu_f_t
    addi x26, x0, -1
bgeu_f_t:
    addi x27, x0, 1

    addi x1, x0, 1
    li   x2, 0x80000000
    bgeu x1, x2, bgeu_f_nt_bad
    addi x28, x0, 1
bgeu_f_nt_bad:
    addi x29, x0, 2

    j bgeu_b_skip
bgeu_b_target:
    addi x30, x0, 3
    j bgeu_b_done
bgeu_b_skip:
    li   x1, 0xFFFFFFFF
    addi x2, x0, 1
    bgeu x1, x2, bgeu_b_target
    addi x31, x0, -1
bgeu_b_done:

bgeu_b_nt_target:
    addi x9, x0, -1
    addi x1, x0, 1
    li   x2, 0xFFFFFFFF
    bgeu x1, x2, bgeu_b_nt_target
    addi x10, x0, 1

    # ================= JAL =================
    jal  x11, jal_fwd
    addi x12, x0, -1
jal_fwd:
    addi x13, x0, 1

    j jal_back_skip
jal_back_target:
    addi x14, x0, 2
    j jal_back_done
jal_back_skip:
    jal  x15, jal_back_target
jal_back_done:

    # ================= JALR =================
    la   x1, jalr_target
    jalr x2, x1, 0
    addi x3, x0, -1
jalr_target:
    addi x4, x0, 1

    la   x1, jalr_target2
    addi x1, x1, 1          # odd address, bit-0 clearing corner
    jalr x5, x1, 0
    addi x6, x0, -1
jalr_target2:
    addi x7, x0, 1

    la   x1, jalr_target3
    jalr x1, x1, 0           # rd == rs1
    addi x8, x0, -1
jalr_target3:
    addi x9, x0, 1

    # ---- SIM_EXIT ----
    li   t0, 0x10000000
    addi a0, x0, 1
    sw   a0, 0(t0)
    sw   zero, 4(t0)
done:
    j done
