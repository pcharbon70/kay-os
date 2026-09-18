OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

SECTIONS
{
    . = 0x200000;
    __image_start = .;

    .text : ALIGN(0x1000)
    {
        KEEP(*(.text.entry))
        *(.text .text.*)
    }

    .rodata : ALIGN(0x1000)
    {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(0x1000)
    {
        *(.data .data.*)
    }

    .bss (NOLOAD) : ALIGN(0x1000)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(16);
        __stack_bottom = .;
        . += 0x4000;
        __stack_top = .;
        __bss_end = .;
    }

    __image_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
