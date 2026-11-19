; Exact native PDP-6 source-extracted SYS_MEMINFO and PROCINFO count tests.
; VM_SPACE_NONE (-1) is not an allocated 0777777-word process image.
        .text
        .globl main
main:
        movei   2,__meminfo
        move    4,proc_table
        setz    1,
        setz    3,
        setz    6,
        pushj   17,sys_meminfo_proc_loop
        jumpn   1,__fail
        move    1,__meminfo+2
        caie    1,06020               ; real resident words + two u-areas
        jrst    __fail_words
        move    1,__meminfo+5
        caie    1,4                   ; includes one ZOMB, excludes FREE
        jrst    __fail_slots
        move    1,__meminfo+6
        caie    1,5
        jrst    __fail_capacity
        move    1,__meminfo+010
        caie    1,020
        jrst    __fail_file

        ; Zombie PROCINFO must report zero logical user words.
        movei   5,__proc_table+3
        movei   2,__procinfo
        pushj   17,v1672_procinfo_words_test
        skipn   __procinfo+3
        jrst    __check_live
        jrst    __fail_zombie
__check_live:
        movei   5,__proc_table
        movei   2,__procinfo
        pushj   17,v1672_procinfo_words_test
        move    1,__procinfo+3
        caie    1,03000
        jrst    __fail_live

        ; Swapped VM has no physical APR but retains logical image size.
        movei   5,__proc_table+6
        movei   2,__procinfo
        pushj   17,v1672_procinfo_words_test
        move    1,__procinfo+3
        caie    1,04000
        jrst    __fail_swapped
        setz    1,
        popj    17,
__fail_words:
        movei   1,011
        popj    17,
__fail_slots:
        movei   1,012
        popj    17,
__fail_capacity:
        movei   1,013
        popj    17,
__fail_file:
        movei   1,014
        popj    17,
__fail_zombie:
        movei   1,015
        popj    17,
__fail_live:
        movei   1,016
        popj    17,
__fail_swapped:
        movei   1,017
        popj    17,
__fail:
        movei   1,1
        popj    17,

        .globl kret_zero
kret_zero:
        setz    1,
        popj    17,

        .data
        .globl proc_table
proc_table:       .word __proc_table
        .globl proc_high_slot
proc_high_slot:   .word 5
        .globl proc_slots
proc_slots:       .word 5

; Each process table entry: meta, vm_state, scheduler.
; High half of vm_state is allocated logical words, low physical base.
; The special all-ones descriptor means VM_SPACE_NONE after EXIT.
__proc_table:
        .word 0400000
        .word 03000,,040000
        .word 0100000,,0

        .word 0
        .word -1
        .word 0500000,,0

        .word 0400000
        .word 04000,,0
        .word 0200000,,0

        .word 0
        .word 02000,,050000
        .word 0300000,,0

        .word 0
        .word -1
        .word 0

        .bss
__meminfo:       .block 011
__procinfo:      .block 5
        .globl __test_exit
__test_exit:     .block 1
