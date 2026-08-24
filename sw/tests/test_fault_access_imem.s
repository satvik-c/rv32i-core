.section .text.init
.globl _start

# Instruction access fault: JALR to the poison address (ACCESS_FAULT_ADDR).

_start:
    li   x1, 0x20000000
    jalr x2, x1, 0
done:
    j done
