; Disposable PDP-6-only MM fragmentation test extension.
; The real allocator makes the extent records and the real BRK runs.
; All private allocations are released by exact base/type/owner.
;
; Before native_sys_brk: (test-only invalid-break sentinels)
        caie    2,0777773
        jrst    v1115_check_release
        jrst    v1115_prepare
v1115_check_release:
        caie    2,0777772
        jrst    v1115_check_cause
        jrst    v1115_release
v1115_check_cause:
        caie    2,0777771
        jrst    v1115_normal_brk
        move    1,v1115_last_cause
        popj    17,
v1115_normal_brk:

; Immediately after the production VM BRK call, before policy checking:
;        movem   2,v1115_last_cause
;
; Definitions appended after the original syscall assembly file.
        .text
        .globl mm_alloc_aligned_noreclaim
        .globl mm_extent_count
        .globl mm_find_fit
        .globl mm_free

v1115_prepare:
        skipn   v1115_count
        jrst    v1115_start
        seto    1,
        popj    17,
v1115_start:
        push    17,010
        push    17,011
        move    1,mm_extent_count
        movem   1,v1115_original_count
        setzm   v1115_last_cause
v1115_allocate_loop:
        move    010,v1115_count
        caige   010,030               ; bounded, 24 real extents max
        jrst    v1115_allocate_one
        jrst    v1115_failed
v1115_allocate_one:
        movei   1,v1115_base
        push    17,1                   ; output base
        push    17,[0]                 ; LOW preference
        movei   1,040000              ; 16K physical words
        movei   2,02000               ; APR-compatible alignment
        movei   3,3                   ; MM_TYPE_KERNEL_DYNAMIC
        setz    4,                    ; owner zero
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        jumpn   1,v1115_allocations_done
        move    010,v1115_count
        move    011,v1115_base
        movem   011,v1115_bases(010)
        aos     v1115_count
        jrst    v1115_allocate_loop
v1115_allocations_done:
        ; The final failed allocation must not be a descriptor failure.
        camn    1,[-3]
        jrst    v1115_failed
        move    1,v1115_count
        caige   1,010                 ; enough holes for 64K free total
        jrst    v1115_failed
        setz    010,
v1115_free_alternates:
        caml    010,v1115_count
        jrst    v1115_check_gaps
        move    1,v1115_bases(010)
        movei   2,3
        setz    3,
        pushj   17,mm_free
        jumpn   1,v1115_failed
        setzm   v1115_bases(010)
        addi    010,2
        jrst    v1115_free_alternates
v1115_check_gaps:
        ; A failing real fit reports total free physical words. Require
        ; enough aggregate RAM for the replacement, but no 64K gap.
        movei   1,0200000
        movei   2,02000
        movei   3,1                   ; HIGH preference, like BRK
        movei   4,v1115_free_words
        pushj   17,mm_find_fit
        jumpn   1,v1115_failed
        move    1,v1115_free_words
        caige   1,0200000
        jrst    v1115_failed
        movei   1,1                   ; prepared (not a BRK result)
        jrst    v1115_prepare_return
v1115_failed:
        setom   v1115_failed_flag
        seto    1,
v1115_prepare_return:
        pop     17,011
        pop     17,010
        popj    17,

v1115_release:
        push    17,010
        setz    010,
v1115_release_next:
        caml    010,v1115_count
        jrst    v1115_release_verify
        skipn   v1115_bases(010)
        jrst    v1115_release_skip
        move    1,v1115_bases(010)
        movei   2,3
        setz    3,
        pushj   17,mm_free
        jumpn   1,v1115_release_free_error
        setzm   v1115_bases(010)
v1115_release_skip:
        aoja    010,v1115_release_next
v1115_release_verify:
        ; BRK's legitimate FS/swap reclamation can remove other extents.
        ; Every tracked test allocation must already have been freed;
        ; reject only an increased descriptor count (possible leak).
        move    1,mm_extent_count
        camle   1,v1115_original_count
        jrst    v1115_release_count_error
        skipn   v1115_failed_flag
        jrst    v1115_release_ok
        movni   1,6                   ; preparation failure
        jrst    v1115_release_return
v1115_release_free_error:
        movni   1,4                   ; typed MM free refused
        jrst    v1115_release_return
v1115_release_count_error:
        movni   1,5                   ; exact descriptor count changed
        jrst    v1115_release_return
v1115_release_ok:
        setzm   v1115_count
        setz    1,
v1115_release_return:
        pop     17,010
        popj    17,

        .bss
v1115_last_cause: .block 1
v1115_free_words: .block 1
v1115_original_count: .block 1
v1115_base: .block 1
v1115_count: .block 1
v1115_failed_flag: .block 1
v1115_bases: .block 030
