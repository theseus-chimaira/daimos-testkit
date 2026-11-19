; K01 v1681: real MM pin refusal in production swap-out transition.
; The source-linked swap-out branch must not publish an unsafe process.

        .text
        .globl main
main:
        ; A stale VM base without any physical MM owner is not runnable.
        setz    1,
        pushj   17,k01_setup
        pushj   17,k01_try_pin
        move    1,k01_invariant_calls
        caie    1,1
        jrst    k01_fail1
        skipn   k01_pin_ok_calls
        jrst    k01_missing_state
        jrst    k01_fail1
k01_missing_state:
        move    1,k01_proc
        trnn    1,0200000
        jrst    k01_fail1
        skipn   mm_extent_count
        jrst    k01_saturated
        jrst    k01_fail1

k01_saturated:
        ; A saturated pin field is an MM_BUSY refusal. It is impossible
        ; to claim an additional pin; neither type nor owner may change.
        movei   1,1
        pushj   17,k01_setup
        move    1,[03771,,01]         ; 255 pins, PROCESS, owner 1
        movem   1,mm_extents+1
        pushj   17,k01_try_pin
        move    1,k01_invariant_calls
        caie    1,1
        jrst    k01_fail2
        move    1,k01_proc
        trnn    1,0200000
        jrst    k01_fail2
        move    1,mm_extents+1
        came    1,[03771,,01]
        jrst    k01_fail2

        ; Normal owner remains in TRANSITION and gains exactly one pin.
        ; This is a pre-publication step; the later swap transaction
        ; is deliberately outside this isolated test.
        movei   1,1
        pushj   17,k01_setup
        pushj   17,k01_try_pin
        skipn   k01_invariant_calls
        jrst    k01_success_state
        jrst    k01_fail3
k01_success_state:
        move    1,k01_pin_ok_calls
        caie    1,1
        jrst    k01_fail3
        move    1,k01_proc
        trnn    1,0200000
        jrst    k01_fail3
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    k01_fail3
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

; AC1 count. One expected PROCESS extent at base 02000.
k01_setup:
        movem   1,mm_extent_count
        move    2,[02000,,02000]
        movem   2,mm_extents
        move    2,[01,,01]
        movem   2,mm_extents+1
        setzm   k01_proc
        setzm   k01_invariant_calls
        setzm   k01_pin_ok_calls
        popj    17,

k01_try_pin:
        push    17,011
        push    17,013
        movei   011,k01_proc
        movei   013,02000
        pushj   17,proc_swap_pin_fragment_v1681
        pop     17,013
        pop     17,011
        popj    17,

; Both targets terminate the extracted fragment without fabricating
; a completed swap transaction. The full source branch remains real.
        .globl proc_swap_pin_ok_v1681
proc_swap_pin_ok_v1681:
        aos     k01_pin_ok_calls
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     k01_invariant_calls
        popj    17,
        .globl proc_swap_out_restore
proc_swap_out_restore:
        popj    17,

        .bss
        .globl __test_exit
        .globl mm_extents
        .globl mm_extent_count
__test_exit:             .block 1
mm_extents:              .block 2
mm_extent_count:         .block 1
k01_proc:                .block 3
k01_invariant_calls:     .block 1
k01_pin_ok_calls:        .block 1
