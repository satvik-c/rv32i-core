.section .text.init
.globl _start

# Repeated FENCE retirements under randomized timing, to give cx_imem_lat (mem_timing_cov.sv)
# enough independent latency draws to close every bucket for this otherwise-rare opcode.

_start:
    fence
    fence
    fence
    fence
    fence
    fence
    fence
    fence
    fence
    fence
    li      t0, 0x10000000
    addi    a0, x0, 1
    sw      a0, 0(t0)
    sw      zero, 4(t0)
done:
    j done
