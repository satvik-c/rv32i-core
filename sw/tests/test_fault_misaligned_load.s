.section .text.init
.globl _start

# Misaligned load: LH at an odd address.

_start:
    li   x1, 0x80101001
    lh   x2, 0(x1)
done:
    j done
