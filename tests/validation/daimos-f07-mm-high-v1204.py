#!/usr/bin/env python3
"""Disposable F07 v1204 high-occupancy MM probe with exact typed rollback.

Only the test copy of syscall_dispatch_pdp6.s is modified. Ordinary
physical allocations use the real non-reclaiming PDP-6 MM allocator.
The owner/lease is checked before pressure is applied, and all owned
extents are freed after the original process tests have finished.
"""

from pathlib import Path
import sys

p = Path(sys.argv[1]) / 'proc/syscall_dispatch_pdp6.s'
s = p.read_text()
anchor = 'native_sys_brk:\n        move    1,2'
assert s.count(anchor) == 1, 'v1204: BRK test entry anchor changed'
code = '''native_sys_brk:
        caie    2,0777762            ; test-only pressure prepare
        jrst    daimos_f07_other_v1204
        move    0,proc_current_slot
        caie    0,1                 ; INIT only
        jrst    kret_neg1
        jrst    daimos_f07_prepare_v1204
daimos_f07_other_v1204:
        caie    2,0777763            ; exact typed release
        jrst    daimos_f07_normal_v1204
        move    0,proc_current_slot
        caie    0,1                 ; INIT only
        jrst    kret_neg1
        jrst    daimos_f07_release_v1204
daimos_f07_normal_v1204:
        move    1,2'''
s = s.replace(anchor, code, 1)
s = '''        .globl proc_current_slot
        .globl fs_provider_ready
        .globl daimos_test_holder_enter_v1150
        .globl daimos_test_predispatch_v1150
        .globl mm_alloc_aligned_noreclaim
        .globl mm_free
''' + s

s += '''
        .text
; Caller is INIT, FS gateway belongs to live slot 6. Only test-owned
; kernel-dynamic extents are added, never user/APR process extents.
; Allocate twelve 020000-word APR-aligned extents (98304 words)
; followed by 96 one-word extents, leaving capacity headroom for
; ordinary teardown and the physical-OOM/swap recovery paths.
daimos_f07_prepare_v1204:
        skipn   daimos_f07_count_v1204
        jrst    daimos_f07_prepare_lease_v1204
        jrst    daimos_f07_bad_v1204
daimos_f07_prepare_lease_v1204:
        move    6,fs_provider_ready
        camn    6,[7,,0]
        jrst    daimos_f07_prepare_enter_v1204
        jrst    daimos_f07_bad_v1204
daimos_f07_prepare_enter_v1204:
        skipn   daimos_test_holder_enter_v1150
        jrst    daimos_f07_bad_v1204
        skipn   daimos_test_predispatch_v1150
        jrst    daimos_f07_bad_v1204
        push    17,010
        push    17,011
        setz    010,
daimos_f07_prepare_next_v1204:
        caige   010,0154             ; 108 extents total
        jrst    daimos_f07_prepare_alloc_v1204
        movei   1,0154
        movem   1,daimos_f07_prepared_v1204
        setz    1,
        jrst    daimos_f07_prepare_return_v1204
daimos_f07_prepare_alloc_v1204:
        movei   1,daimos_f07_base_v1204
        push    17,1                ; 6th argument: basep
        push    17,[0]              ; 5th argument: MM_ALLOC_LOW
        caige   010,014             ; first twelve: 8K words each
        jrst    daimos_f07_prepare_big_v1204
        movei   1,1                ; small descriptor pressure
        movei   2,1                ; word alignment
        jrst    daimos_f07_prepare_call_v1204
daimos_f07_prepare_big_v1204:
        movei   1,020000
        movei   2,02000            ; real APR relocation quantum
daimos_f07_prepare_call_v1204:
        movei   3,3                ; MM_TYPE_KERNEL_DYNAMIC
        movei   4,075              ; unique test owner
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        jumpn   1,daimos_f07_prepare_failed_v1204
        move    011,daimos_f07_base_v1204
        movem   011,daimos_f07_bases_v1204(010)
        aos     daimos_f07_count_v1204
        aoja    010,daimos_f07_prepare_next_v1204
daimos_f07_prepare_failed_v1204:
        setom   daimos_f07_error_v1204
        ; Do not leave partial pressure behind if allocation fails.
        pushj   17,daimos_f07_cleanup_v1204
        seto    1,
daimos_f07_prepare_return_v1204:
        pop     17,011
        pop     17,010
        popj    17,

; On the normal path, release after the OOM process and foreign provider
; have both completed. Exactly the original base/type/owner is passed.
daimos_f07_release_v1204:
        move    6,daimos_f07_prepared_v1204
        caie    6,0154
        jrst    daimos_f07_bad_v1204
        push    17,010
        push    17,011
        pushj   17,daimos_f07_cleanup_v1204
        pop     17,011
        pop     17,010
        popj    17,

; Private cleanup uses no new MM allocation. On a wrong-owner failure,
; do not discard the still-owned base or claim successful recovery.
daimos_f07_cleanup_v1204:
        move    010,daimos_f07_count_v1204
daimos_f07_cleanup_next_v1204:
        jumpe   010,daimos_f07_cleanup_done_v1204
        soj     010,
        move    1,daimos_f07_bases_v1204(010)
        movei   2,3
        movei   3,075
        pushj   17,mm_free
        jumpn   1,daimos_f07_cleanup_fail_v1204
        setzm   daimos_f07_bases_v1204(010)
        movem   010,daimos_f07_count_v1204
        aos     daimos_f07_freed_v1204
        jrst    daimos_f07_cleanup_next_v1204
daimos_f07_cleanup_fail_v1204:
        setom   daimos_f07_error_v1204
        seto    1,
        popj    17,
daimos_f07_cleanup_done_v1204:
        setz    1,
        popj    17,
daimos_f07_bad_v1204:
        setom   daimos_f07_error_v1204
        seto    1,
        popj    17,

        .bss
        .globl daimos_f07_count_v1204
daimos_f07_count_v1204: .block 1
        .globl daimos_f07_prepared_v1204
daimos_f07_prepared_v1204: .block 1
        .globl daimos_f07_freed_v1204
daimos_f07_freed_v1204: .block 1
        .globl daimos_f07_error_v1204
daimos_f07_error_v1204: .block 1
daimos_f07_base_v1204: .block 1
daimos_f07_bases_v1204: .block 0154
'''
p.write_text(s)
