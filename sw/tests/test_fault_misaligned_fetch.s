.section .text.init
.globl _start

# Misaligned fetch: JALR clears target bit 0 but not bit 1, so a target
# with bit 1 set faults.

_start:
    la   x1, target
    addi x1, x1, 2
    jalr x2, x1, 0
    addi x3, x0, -1
target:
    addi x4, x0, 1
done:
    j done
