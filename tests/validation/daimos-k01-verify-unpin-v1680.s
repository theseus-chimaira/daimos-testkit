; K01 v1680: execute the production PURE verify-failure MM rollback.
; Real PDP-6 mm_unpin must guard the process TRANSITION publication.

        .text
        .globl main
main:
        ; Normal verification rejection: one real physical pin is released.
        movei   1,1
        pushj   17,k01_setup
        move    1,k01_proc
        came    1,[0200000]
        jrst    k01_fail1
        move    1,[011,,01]           ; one pin, PROCESS, owner 1
        movem   1,mm_extents+1
        pushj   17,k01_rollback
        skipn   k01_invariant_calls
        jrst    k01_case1_state
        jrst    k01_fail1
k01_case1_state:
        move    1,k01_proc
        trne    1,0200000             ; TRANSITION must be cleared
        jrst    k01_fail1
        move    1,mm_extents+1
        came    1,[01,,01]            ; pin is gone, owner unchanged
        jrst    k01_fail1
        move    1,k01_result
        came    1,[-1]                ; ordinary failed swap return
        jrst    k01_fail1

        ; Corrupt pin accounting: no pin is held, unpin returns MM_INVAL.
        ; A missing pin is NOT permission to make the process runnable.
        movei   1,1
        pushj   17,k01_setup
        move    1,[01,,01]
        movem   1,mm_extents+1
        pushj   17,k01_rollback
        move    1,k01_invariant_calls
        caie    1,1
        jrst    k01_fail2
        move    1,k01_proc
        trnn    1,0200000
        jrst    k01_fail2
        move    1,mm_extents+1
        came    1,[01,,01]            ; never invent/decrement a pin
        jrst    k01_fail2

        ; Lost MM descriptor: unpin cannot prove who owns the memory.
        ; Do not publish a runnable image or manufacture a replacement.
        setz    1,
        pushj   17,k01_setup
        pushj   17,k01_rollback
        move    1,k01_invariant_calls
        caie    1,1
        jrst    k01_fail3
        move    1,k01_proc
        trnn    1,0200000
        jrst    k01_fail3
        skipn   mm_extent_count
        jrst    k01_pass
        jrst    k01_fail3

k01_pass:
        setz    1,
        popj    17,
k01_fail1:
        movei   1,1
        popj    17,
k01_fail2:
        movei   1,2
        popj    17,
k01_fail3:
        movei   1,3
        popj    17,

; AC1: initial count. Set up one exact PROCESS extent at physical 02000.
k01_setup:
        movem   1,mm_extent_count
        move    2,[02000,,02000]
        movem   2,mm_extents
        move    2,[01,,01]
        movem   2,mm_extents+1
        movei   2,0200000
        movem   2,k01_proc
        setzm   k01_invariant_calls
        setzm   k01_result
        popj    17,

; The called entry is extracted verbatim from proc_swap_pdp6.s.
; Only the external transaction frame/return landing is supplied here.
k01_rollback:
        push    17,011
        movei   011,k01_proc
        movei   015,0
        movei   013,02000
        pushj   17,k01_verify_entry
        pop     17,011
        popj    17,
k01_verify_entry:
        jrst    proc_swap_out_verify_fail

; Branch target in production is a fail-stop. This fixture records its
; invocation and leaves the untouched MM descriptor available to inspect.
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     k01_invariant_calls
        jrst    k01_landed

; The normal swap-out epilogue needs no real frame here: caller metadata
; and the production transition-clear block are under test, not its ABI.
        .globl proc_swap_out_restore
proc_swap_out_restore:
k01_landed:
        movem   1,k01_result
        popj    17,

        .bss
        .globl mm_extents
        .globl mm_extent_count
        .globl __test_exit
        .globl k01_proc
        .globl k01_invariant_calls
        .globl k01_result
mm_extents:             .block 2
mm_extent_count:       .block 1
k01_proc:              .block 3
k01_invariant_calls:   .block 1
k01_result:            .block 1
__test_exit:           .block 1
