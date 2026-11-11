; v1471: real VM destroy must not release the last XIP pin before a
; fallible swap/backing detach. These mocks are inherited from the v1094
; source-linked hardware fault fixture, with its original main renamed.
        .text
        .globl main
main:
        pushj   17,reset_v1094
        movei   0,1
        movem   0,xip_owned_v1094
        setom   detach_result_v1094
        movei   0,011
        movem   0,stage_v1094
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_failed_v1471
        jrst    fail_v1471
check_failed_v1471:
        move    0,descriptor_v1094+1
        came    0,[04000,,012000]
        jrst    fail_v1471
        move    0,xip_owned_v1094
        caie    0,1                    ; pin must still be owned
        jrst    fail_v1471
        skipn   unpin_calls_v1094     ; MM unpin MUST NOT have been called
        jrst    check_detach_v1471
        jrst    fail_v1471
check_detach_v1471:
        move    0,detach_calls_v1094
        caie    0,1
        jrst    fail_v1471
        skipn   mm_calls_v1094        ; no process-MM fallback
        jrst    try_recovered_v1471
        jrst    fail_v1471
try_recovered_v1471:
        setzm   detach_result_v1094
        movei   0,012
        movem   0,stage_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1471
        move    0,descriptor_v1094+1
        camn    0,[-1]
        jrst    check_released_v1471
        jrst    fail_v1471
check_released_v1471:
        skipn   xip_owned_v1094
        jrst    check_release_count_v1471
        jrst    fail_v1471
check_release_count_v1471:
        move    0,unpin_calls_v1094
        caie    0,1
        jrst    fail_v1471
        move    0,detach_calls_v1094
        caie    0,2
        jrst    fail_v1471
        skipn   mm_calls_v1094
        jrst    check_unpin_error_v1471
        jrst    fail_v1471
check_unpin_error_v1471:
        ; The reverse failure order is also safe: once an XIP resident
        ; record is detached (no PURE/disk payload), MM unpin can refuse.
        ; The still-owned pin and VM are retryable even though the now
        ; empty resident backing record need not be reconstructed.
        pushj   17,reset_v1094
        movei   0,1
        movem   0,xip_owned_v1094
        setom   unpin_result_v1094
        movei   0,013
        movem   0,stage_v1094
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_unpin_still_owned_v1471
        jrst    fail_v1471
check_unpin_still_owned_v1471:
        move    0,descriptor_v1094+1
        came    0,[04000,,012000]
        jrst    fail_v1471
        move    0,xip_owned_v1094
        caie    0,1
        jrst    fail_v1471
        move    0,unpin_calls_v1094
        caie    0,1
        jrst    fail_v1471
        move    0,detach_calls_v1094
        caie    0,1
        jrst    fail_v1471
        skipn   mm_calls_v1094
        jrst    repair_unpin_v1471
        jrst    fail_v1471
repair_unpin_v1471:
        setzm   unpin_result_v1094
        movei   0,014
        movem   0,stage_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1471
        move    0,descriptor_v1094+1
        camn    0,[-1]
        jrst    check_retry_end_v1471
        jrst    fail_v1471
check_retry_end_v1471:
        skipn   xip_owned_v1094
        jrst    check_retry_count_v1471
        jrst    fail_v1471
check_retry_count_v1471:
        move    0,unpin_calls_v1094
        caie    0,2
        jrst    fail_v1471
        move    0,detach_calls_v1094
        caie    0,2
        jrst    fail_v1471
        skipn   mm_calls_v1094
        jrst    check_normal_base_v1471
        jrst    fail_v1471
check_normal_base_v1471:
        ; The read-only XIP query may overwrite AC3. Ordinary private
        ; process-VM teardown must use the stacked original physical
        ; base when falling back to MM_TYPE_PROCESS after a non-XIP query.
        pushj   17,reset_v1094
        movei   0,015
        movem   0,stage_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1471
        move    0,mm_calls_v1094
        caie    0,1
        jrst    fail_v1471
        move    0,detach_calls_v1094
        caie    0,1
        jrst    fail_v1471
        skipn   extent_owned_v1094
        jrst    check_normal_none_v1471
        jrst    fail_v1471
check_normal_none_v1471:
        move    0,descriptor_v1094+1
        camn    0,[-1]
        jrst    check_normal_provider_v1471
        jrst    fail_v1471
check_normal_provider_v1471:
        ; Provider must receive the actual saved physical base, not a
        ; clobbered scratch register; MM success alone can mask a faulty
        ; provider call when a loaded provider returns the absent sentinel.
        move    0,release_input_v1471
        caie    0,012000
        jrst    fail_v1471
        skipn   error_v1094
        jrst    pass_v1471
        jrst    fail_v1471
pass_v1471:
        setz    1,
        popj    17,
fail_v1471:
        move    1,stage_v1094
        popj    17,

        .data
release_input_v1471: .word 0
