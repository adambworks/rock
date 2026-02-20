OUTPUT_FORMAT("elf64-x86-64")
ENTRY(_start)

SECTIONS
{
    . = 0x100000; /* load kernel at 1MB */

    .text._start ALIGN(1) :
    {
        KEEP(*(.text._start))   /* kernel entry */
    }

    .text :
    {
        *(.text*)         /* all other code */
    }

    .rodata :
    {
        *(.rodata*)
    }

    .data :
    {
        *(.data*)
    }

    .bss :
    {
        __bss_start = .;
        *(.bss*)
        __bss_end = .;
    }
}
