.section .text.init
.globl _start

# Misaligned store: SW at a non-word-aligned address.

_start:
    li   x1, 0x80101001
    li   x2, 0xDEADBEEF
    sw   x2, 0(x1)
done:
    j done
