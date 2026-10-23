; v216 native PDP-6 XIP user lifecycle fixture.
; The user image executes MOVEI and monitor UUO only; neither writes user
; memory, uses a user stack, nor exposes writable shared globals.
; A monitor trap transfers control to executive memory for validation and
; release via the real production vm_space_destroy().
        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        setzm   test_xip_monitor_marker_v216
        move    1,[jsr test_xip_monitor_trap_v216]
        movem   1,000041            ; PDP-6 monitor UUO vector
        pushj   17,daimos_memfs_pdp6_test
        movem   1,daimos_memfs_pdp6_result
        jumpn   1,test_xip_halt_v216
        move    1,daimos_memfs_xip_user_base_v209
        hrrm    1,test_xip_user_apr_v216
        datao   0000,test_xip_user_apr_v216
        jrst    1,020               ; user fetch from MEMFS at base+020
test_xip_halt_v216:
        halt    .

; Entered in executive mode by hardware JSR at low-core 041, after the
; user-mode monitor UUO at logical 021. AC2 retains the value set by MOVEI.
test_xip_monitor_trap_v216:
        .word   0
        movem   2,test_xip_monitor_marker_v216
        pushj   17,daimos_memfs_xip_finish_v216
        movem   1,daimos_memfs_pdp6_result
        halt    .

        .globl  test_xip_instruction_template
test_xip_instruction_template:
        movei   2,01234
        .globl  test_xip_user_instruction_exit_v216
test_xip_user_instruction_exit_v216:
        .word   040000000000       ; monitor UUO 040, no user-memory write

; Required by the shared MEMFS native fixture (other branches unused here).
        .globl  test_xip_execute_word
test_xip_execute_word:
        move    5,1
        setz    2,
        xct     (5)
        move    1,2
        popj    17,
        .globl  proc_wait_event
proc_wait_event:
        setz    1,
        popj    17,
        .globl  proc_wakeup_event
proc_wakeup_event:
        popj    17,

        .data
; vm_enter_initial_user uses LH=(user_words-02000)+1. One 02000-word
; allocation therefore requires LH=1, NOT zero (SIMH enforces that bound).
test_xip_user_apr_v216: .word 000001000000
        .bss
        .globl  test_xip_monitor_marker_v216
test_xip_monitor_marker_v216: .block 1
        .globl  fs_block_workspace
fs_block_workspace: .block 0200
stack:  .block 0200
