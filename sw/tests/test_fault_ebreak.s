.section .text.init
.globl _start

# EBREAK: legal encoding, halts the core per Stage 1 policy.

_start:
    # leading nops so ebreak isn't the first post-reset fetch (which always sees zero latency)
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    ebreak
done:
    j done
