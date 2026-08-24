.section .text.init
.globl _start

# Startup for compiled-C tests: stack, .bss zero, call main, return code to SIM_EXIT.

_start:
    # Zero every GPR before use
    .irp reg,x1,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,x21,x22,x23,x24,x25,x26,x27,x28,x29,x30,x31
    li \reg, 0
    .endr

    la   sp, __stack_top

    la   t0, __bss_start
    la   t1, __bss_end
1:
    bge  t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    call main

    li   t0, 0x10000000
    slli a0, a0, 1
    ori  a0, a0, 1
    sw   a0, 0(t0)
    sw   zero, 4(t0)
3:
    j    3b
