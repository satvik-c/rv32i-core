.section .text.init
.globl _start

# EBREAK: legal encoding, halts the core per Stage 1 policy.

_start:
    ebreak
done:
    j done
