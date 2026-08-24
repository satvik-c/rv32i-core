.section .text.init
.globl _start

# Illegal instruction: all-zero word.

_start:
    .word 0x00000000
done:
    j done
