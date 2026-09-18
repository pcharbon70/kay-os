OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

PHDRS
{
    text PT_LOAD FLAGS(5);
    rodata PT_LOAD FLAGS(4);
    data PT_LOAD FLAGS(6);
}

KERNEL_VIRTUAL_BASE = 0xffffffff80000000;
KERNEL_PHYSICAL_BASE = 0x00200000;

SECTIONS
{
    . = KERNEL_VIRTUAL_BASE;
    __image_start = .;

    .text ALIGN(0x1000) : AT(ADDR(.text) - KERNEL_VIRTUAL_BASE + KERNEL_PHYSICAL_BASE)
    {
        KEEP(*(.text.entry))
        *(.text .text.*)
    } :text

    .rodata ALIGN(0x1000) : AT(ADDR(.rodata) - KERNEL_VIRTUAL_BASE + KERNEL_PHYSICAL_BASE)
    {
        *(.rodata .rodata.*)
    } :rodata

    .data ALIGN(0x1000) : AT(ADDR(.data) - KERNEL_VIRTUAL_BASE + KERNEL_PHYSICAL_BASE)
    {
        KEEP(*(.limine_requests_start))
        KEEP(*(.limine_requests))
        KEEP(*(.limine_requests_end))
        *(.data .data.*)
    } :data

    .bss ALIGN(0x1000) (NOLOAD) : AT(ADDR(.bss) - KERNEL_VIRTUAL_BASE + KERNEL_PHYSICAL_BASE)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(16);
        __stack_bottom = .;
        . += 0x4000;
        __stack_top = .;
        __bss_end = .;
    } :data

    __image_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}

ASSERT((_start >= KERNEL_VIRTUAL_BASE), "entry is not in the higher half")
ASSERT((__stack_top & 0xf) == 0, "stack top is not 16-byte aligned")
ASSERT((__stack_top - __stack_bottom) == 0x4000, "stack size drift")
