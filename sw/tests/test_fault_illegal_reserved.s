.section .text.init
.globl _start

# Illegal instruction: reserved opcode, rs1/rs2/rd all x0 (registers are
# indeterminate until written, so this avoids reading an unwritten one).

_start:
    .word 0x0000007F
done:
    j done
