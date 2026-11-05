OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    SDRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64M
}

SECTIONS
{
    . = ORIGIN(SDRAM);

    .init : ALIGN(4)
    {
        KEEP(*(.init))
    } > SDRAM

    .text : ALIGN(4)
    {
        *(.text .text.*)
    } > SDRAM

    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.*)
    } > SDRAM

    .data : ALIGN(4)
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > SDRAM

    PROVIDE(__global_pointer$ = . + 0x800);

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        __bss_end = .;
    } > SDRAM

    . = ALIGN(16);
    __heap_start = .;

    __stack_top = ORIGIN(SDRAM) + LENGTH(SDRAM) - 16;
}