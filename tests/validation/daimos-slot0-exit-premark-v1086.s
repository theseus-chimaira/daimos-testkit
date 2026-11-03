; Exercise actual proc_exit_current before its irreversible stack switch.
; The mock C exit_finish checks the descriptor received at the PI6-masked
; handoff. It must already carry the existing PREVM + FINALIZE stage.
        .text
        .globl main
main:
        movei 17,__userstack-1
        hrli 17,-0400
        setzm __test_exit
        movei 1,01234
        jrst proc_exit_current

        .globl mach_pi_disable
mach_pi_disable:
        movei 1,0202          ; PI formerly globally enabled and PI6
        popj 17,

        .globl proc_exit_finish
proc_exit_finish:
        move 2,__proc
        trnn 2,0200000       ; TRANSITION must be set
        jrst fail_trans_v1086
        move 2,__uarea+067
        hlrz 3,2
        caie 3,0500000       ; FINALIZE | PREVM
        jrst fail_marker_v1086
        hrrz 2,2
        caie 2,01234         ; retain original exit status
        jrst fail_status_v1086
        skipn file_table
        jrst finish_good_v1086
        jrst fail_fd_v1086
finish_good_v1086:
        skipn __test_exit
        jrst finish_return_v1086
        jrst fail_extra_v1086
finish_return_v1086:
        movei 1,1            ; a user remains, so resume idle
        popj 17,
fail_trans_v1086: movei 2,1
        jrst fail_exit_v1086
fail_marker_v1086: movei 2,2
        jrst fail_exit_v1086
fail_status_v1086: movei 2,3
        jrst fail_exit_v1086
fail_fd_v1086: movei 2,4
        jrst fail_exit_v1086
fail_extra_v1086: movei 2,5
fail_exit_v1086:
        movem 2,__test_exit
        movei 1,1
        popj 17,

        .globl proc_idle_loop
proc_idle_loop:
        jrst 4,0

        .data
        .globl mach_kernel_stack_base
mach_kernel_stack_base: .word __idlestack-1
        .globl proc_current_ptr
proc_current_ptr: .word __proc
        .globl proc_current_slot
proc_current_slot: .word 2
        .globl file_table
file_table: .word __uarea+026
__proc: .word __uarea,,0400407
        .word 04000,,020000
        .word 0100024,,0
__uarea: .block 0410
        .bss
__userstack: .block 0400
__idlestack: .block 0400
        .globl __test_exit
__test_exit: .block 1
