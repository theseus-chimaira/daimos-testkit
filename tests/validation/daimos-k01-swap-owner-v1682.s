; K01 v1682: exact live MM type/owner/size validation after swap-out pin.
; Real PDP-6 MM leaves, extracted production swap-out preflight branch.

        .text
        .globl main
main:
        ; Wrong slot owner: pin acquisition alone cannot make this RAM
        ; a valid process image. The extra pin stays held on refusal.
        move    1,[02000,,02000]
        move    2,[01,,02]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[011,,02]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail1

        ; Wrong extent type with the expected numerical owner.
        move    1,[02000,,02000]
        move    2,[03,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[013,,01]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail2

        ; Wrong physical size. Never trust only the VM base and owner.
        move    1,[04000,,02000]
        move    2,[01,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[011,,01]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail3

        ; Already pinned at entry: reaching the leaf despite a stale
        ; preflight must never silently turn one pin into two.
        move    1,[02000,,02000]
        move    2,[011,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[021,,01]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail4

        ; Exact PROCESS, slot 1, size 02000 and zero previous pins:
        ; the transaction may proceed, keeping its new pin until commit.
        move    1,[02000,,02000]
        move    2,[01,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        skipn   k01_invariant_calls
        jrst    k01_valid
        jrst    k01_fail5
k01_valid:
        move    1,k01_success_calls
        caie    1,1
        jrst    k01_fail5
        move    1,k01_proc
        trnn    1,0200000
        jrst    k01_fail5
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    k01_fail5
        setz    1,
        popj    17,

k01_fail1: movei 1,1
        popj    17,
k01_fail2: movei 1,2
        popj    17,
k01_fail3: movei 1,3
        popj    17,
k01_fail4: movei 1,4
        popj    17,
k01_fail5: movei 1,5
        popj    17,

; AC1 is the span, AC2 is the MM metadata. Preserve both values.
k01_setup:
        movem   1,mm_extents
        movem   2,mm_extents+1
        movei   3,1
        movem   3,mm_extent_count
        setzm   k01_proc
        setzm   k01_invariant_calls
        setzm   k01_success_calls
        popj    17,

k01_try:
        push    17,010
        push    17,011
        push    17,013
        push    17,014
        movei   010,1
        movei   011,k01_proc
        movei   013,02000
        movei   014,02000
        pushj   17,proc_swap_pin_verify_fragment_v1682
        pop     17,014
        pop     17,013
        pop     17,011
        pop     17,010
        popj    17,

; AC1 contains the expected exact MM metadata after pin acquisition.
k01_expect_refusal:
        move    2,mm_extents+1
        camn    1,2
        jrst    k01_refusal_metadata
        jrst    k01_expect_bad
k01_refusal_metadata:
        move    2,k01_invariant_calls
        caie    2,1
        jrst    k01_expect_bad
        skipn   k01_success_calls
        jrst    k01_refusal_transition
        jrst    k01_expect_bad
k01_refusal_transition:
        move    2,k01_proc
        trnn    2,0200000
        jrst    k01_expect_bad
        setz    1,
        popj    17,
k01_expect_bad:
        seto    1,
        popj    17,

        .globl proc_swap_pin_done_v1682
proc_swap_pin_done_v1682:
        aos     k01_success_calls
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     k01_invariant_calls
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
k01_success_calls:       .block 1
