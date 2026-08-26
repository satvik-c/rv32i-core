.section .text.init
.globl _start

# ECALL: legal encoding, halts the core per Stage 1 policy.

_start:
    # leading nops so ecall isn't the first post-reset fetch (which always sees zero latency)
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    ecall
done:
    j done
