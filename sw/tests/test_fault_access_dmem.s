.section .text.init
.globl _start

# Data access fault: load from the poison address (ACCESS_FAULT_ADDR).

_start:
    li   x1, 0x20000000
    lw   x2, 0(x1)
done:
    j done
