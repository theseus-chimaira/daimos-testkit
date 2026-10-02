        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,daimos_memfs_pdp6_test
        movem   1,daimos_memfs_pdp6_result
        halt    .

; The standalone provider harness is single-process, so the shared-provider
; lock can never contend.  Satisfy the resident scheduler hooks used by the
; production fs_mres wrapper without pulling the scheduler into this unit test.
        .globl  proc_wait_event
proc_wait_event:
        setz    1,
        popj    17,

        .globl  proc_wakeup_event
proc_wakeup_event:
        popj    17,

        .bss
        .globl  fs_block_workspace
fs_block_workspace:
        .block  0200
stack:  .block  0200
