.section .text.init
.globl _start

# ECALL: legal encoding, halts the core per Stage 1 policy.

_start:
    ecall
done:
    j done
