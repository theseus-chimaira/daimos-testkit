; Test-only PDP-6 kernel extension, inserted only in disposable images.
; The production BRK syscall remains unchanged; two impossible logical
; break requests acquire/release real MM_TYPE_KERNEL_DYNAMIC extents.
; This is a private testing protocol, not an exported kernel feature.

; Insert directly after native_sys_brk: in the disposable copy.
        caie    2,0777776
        jrst    v1114_maybe_release
        jrst    v1114_fill
v1114_maybe_release:
        caie    2,0777775
        jrst    v1114_maybe_run_cause
        jrst    v1114_release
v1114_maybe_run_cause:
        caie    2,0777774
        jrst    v1114_maybe_vm_cause
        move    1,v1116_last_run_cause
        popj    17,
v1114_maybe_vm_cause:
        caie    2,0777770
        jrst    v1114_normal_brk
        move    1,v1116_last_vm_cause
        popj    17,
v1114_normal_brk:

; Definitions appended after the original syscall assembly file.
        .text
        .globl mm_alloc_aligned_noreclaim
        .globl mm_extent_count
        .globl mm_extent_capacity
        .globl mm_free
        .globl v1116_last_run_cause
        .globl v1116_last_vm_cause

v1114_fill:
        skipn   v1114_count
        jrst    v1114_fill_start
        seto    1,
        popj    17,
v1114_fill_start:
        push    17,010
        push    17,011
        movni   1,7                   ; no allocation observed yet
        movem   1,v1116_last_vm_cause
        movem   1,v1116_last_run_cause
        move    1,mm_extent_count
        movem   1,v1114_original_count
v1114_fill_loop:
        move    1,mm_extent_count
        camge   1,mm_extent_capacity
        jrst    v1114_fill_one
        move    1,v1114_count
        jumpe   1,v1114_fill_fail
        ; Actual descriptor count reached the live configured capacity.
        movem   1,v1114_last_count
        setz    1,
        jrst    v1114_fill_return
v1114_fill_one:
        move    1,v1114_count
        caige   1,040                  ; bounded test-only base list
        jrst    v1114_fill_allocate
        jrst    v1114_fill_fail
v1114_fill_allocate:
        movei   1,v1114_base
        push    17,1                   ; six: output base address
        push    17,[1]                 ; five: HIGH preference
        movei   1,1                    ; one physical word
        movei   2,1                    ; alignment = one word
        movei   3,3                    ; kernel-dynamic MM type
        setz    4,                     ; owner zero
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        jumpn   1,v1114_fill_fail
        move    010,v1114_count
        move    011,v1114_base
        movem   011,v1114_bases(010)
        aos     v1114_count
        jrst    v1114_fill_loop
v1114_fill_fail:
        setom   v1114_failed
        seto    1,
v1114_fill_return:
        pop     17,011
        pop     17,010
        popj    17,

v1114_release:
        push    17,010
        push    17,011
v1114_release_next:
        skipn   v1114_count
        jrst    v1114_release_done
        move    010,v1114_count
        soj     010,
        move    1,v1114_bases(010)
        movei   2,3                    ; exact kernel-dynamic type
        setz    3,                     ; exact owner zero
        pushj   17,mm_free
        jumpn   1,v1114_release_error
        movem   010,v1114_count
        jrst    v1114_release_next
v1114_release_error:
        setom   v1114_failed
        seto    1,
        jrst    v1114_release_return
v1114_release_done:
        skipn   v1114_failed
        jrst    v1114_release_ok
        seto    1,
        jrst    v1114_release_return
v1114_release_ok:
        setz    1,
v1114_release_return:
        pop     17,011
        pop     17,010
        popj    17,

        .bss
v1114_original_count: .block 1
v1114_last_count: .block 1
v1114_base: .block 1
v1114_count: .block 1
v1114_failed: .block 1
v1114_bases: .block 040
v1116_last_run_cause: .block 1
v1116_last_vm_cause: .block 1
