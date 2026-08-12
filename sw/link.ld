OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x80000000, LENGTH = 0x00100000
    RAM (rwx) : ORIGIN = 0x80100000, LENGTH = 0x00100000
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > ROM

    .rodata : ALIGN(4) {
        *(.rodata .rodata.*)
    } > ROM

    .data : ALIGN(4) {
        *(.data .data.*)
    } > RAM

    .bss : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(16);
    . = . + 0x2000;
    __stack_top = .;
}
