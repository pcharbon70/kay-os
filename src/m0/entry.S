.section .text.entry,"ax",@progbits
.global _start
.type _start,@function
.extern __stack_top
.extern kay_fixture_main

_start:
    lea __stack_top(%rip), %rsp
    xor %rbp, %rbp
    call kay_fixture_main

.Lhalt:
    cli
    hlt
    jmp .Lhalt

.size _start, . - _start

.section .note.GNU-stack,"",@progbits
