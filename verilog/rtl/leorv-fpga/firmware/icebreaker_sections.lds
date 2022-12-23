# 0 "firmware/sections.lds"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "firmware/sections.lds"
OUTPUT_ARCH(riscv)
# 11 "firmware/sections.lds"
MEMORY {
 ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x800
}

SECTIONS {
    .text : {
        . = ALIGN(4);
        *(.reset_vector*)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        . = ALIGN(4);
        _etext = .;
    } >ram

    .data : {
        . = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } >ram

    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >ram

    . = ALIGN(4);
    end = .;
}

PROVIDE(_stack = ORIGIN(ram) + LENGTH(ram));
