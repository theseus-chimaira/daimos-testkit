; Test-only PDP-6 user APR execution from a pinned MEMFS physical extent.
; The user program deliberately stores into its own backing as a hardware
; counterexample to claims that PDP-6 APR makes shared text immutable.
        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,daimos_memfs_pdp6_test
        movem   1,daimos_memfs_pdp6_result
        jumpn   1,stop
        move    1,daimos_memfs_xip_user_base_v209
        hrrm    1,user_apr
        datao   0000,user_apr
        jrst    1,020
stop:   halt    .

        .globl  test_xip_execute_word
test_xip_execute_word:
        move    5,1
        setz    2,
        xct     (5)
        move    1,2
        popj    17,

        .globl  test_xip_instruction_template
test_xip_instruction_template:
        movei   2,01234
        .globl  test_xip_user_instruction_store_v209
test_xip_user_instruction_store_v209:
        movem   2,030
        .globl  test_xip_user_instruction_halt_v209
test_xip_user_instruction_halt_v209:
        halt    .

        .globl  proc_wait_event
proc_wait_event:
        setz    1,
        popj    17,
        .globl  proc_wakeup_event
proc_wakeup_event:
        popj    17,

        .data
user_apr: .word 0
        .bss
        .globl  fs_block_workspace
fs_block_workspace: .block 0200
stack:   .block 0200
