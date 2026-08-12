.section .text.init
.globl _start

_start:
    addi    x1, x0, 5
    addi    x2, x0, 3
    add     x3, x1, x2
    lui     x4, 0x80100
    sw      x3, 0(x4)
    lw      x5, 0(x4)
    beq     x1, x1, 1f
    addi    x6, x0, -1
    j       2f
1:
    addi    x6, x0, 42
2:
    jal     x7, 3f
    addi    x8, x0, -1
3:
    # SIM_EXIT: store bit0=1 to 0x10000000 to terminate testbench
    li      t0, 0x10000000
    addi    a0, x0, 1
    sw      a0, 0(t0)
    sw      zero, 4(t0)
4:  j       4b
