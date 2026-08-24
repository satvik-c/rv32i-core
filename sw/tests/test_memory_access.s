.section .text.init
.globl _start

# test_memory_access: Load/Store Width x Byte Offset x Load Extension cross
# from vPlan Section 8 -- SB at every byte offset (0-3), SH at every halfword
# offset (0,2), SW at word offset 0, each paired with a store-then-load round
# trip proving wstrb masking preserves the untouched bytes, and LB/LBU,
# LH/LHU signed-vs-unsigned extension pairs. Correctness is verified by the
# spike co-simulation scoreboard.

_start:
    li x2, 0x80101000        # scratch word-aligned base

    # ---- SW/LW word round trip ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0xAAAAAAAA
    sw   x3, 0(x2)
    lw   x4, 0(x2)

    # ---- SB masking round trip + LB/LBU pair, byte offset 0 ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0xAA
    sb   x3, 0(x2)
    lw   x5, 0(x2)
    lb   x6, 0(x2)
    lbu  x7, 0(x2)

    # ---- byte offset 1 ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0xBB
    sb   x3, 1(x2)
    lw   x8, 0(x2)
    lb   x9, 1(x2)
    lbu  x10, 1(x2)

    # ---- byte offset 2 ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0xCC
    sb   x3, 2(x2)
    lw   x11, 0(x2)
    lb   x12, 2(x2)
    lbu  x13, 2(x2)

    # ---- byte offset 3 ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0xDD
    sb   x3, 3(x2)
    lw   x14, 0(x2)
    lb   x15, 3(x2)
    lbu  x16, 3(x2)

    # ---- SH masking round trip + LH/LHU pair, halfword offset 0 ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0x8001
    sh   x3, 0(x2)
    lw   x17, 0(x2)
    lh   x18, 0(x2)
    lhu  x19, 0(x2)

    # ---- halfword offset 2 ----
    li   x1, 0x11111111
    sw   x1, 0(x2)
    li   x3, 0x8002
    sh   x3, 2(x2)
    lw   x20, 0(x2)
    lh   x21, 2(x2)
    lhu  x22, 2(x2)

    fence

    # ---- SIM_EXIT ----
    li   t0, 0x10000000
    addi a0, x0, 1
    sw   a0, 0(t0)
    sw   zero, 4(t0)
done:
    j done
