        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,daimos_memfs_pdp6_test
        movem   1,daimos_memfs_pdp6_result
        halt    .

; Test-only executive XCT probe: fetch an actual instruction directly from
; the pinned MEMFS address without copying the code to a process extent.
; This tests native instruction execution, NOT user-mode APR or EXEC/RUN.
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
