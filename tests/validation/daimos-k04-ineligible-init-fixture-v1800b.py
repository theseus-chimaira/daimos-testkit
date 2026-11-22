#!/usr/bin/env python3
"""Disposable K04 v1800-B physical INIT FILE and parent PREVM faults.

PID1 retains a real FD3 vnode in a fatal private FILE continuation
until PID4's normal terminal FREE path executes. PID3 separately
pins its exact VM through real mm_pin/mm_unpin. No production state
or process descriptor is manufactured by these hooks.
"""
from pathlib import Path
import sys


def one(source, old, new):
    count = source.count(old)
    if count != 1:
        raise ValueError('source anchor changed (%d): %s' %
                         (count, old[:80]))
    return source.replace(old, new, 1)


def install(kernel):
    if kernel.name != 'kernel' or 'v1800b' not in str(kernel):
        raise ValueError('expected v1800b copied kernel directory')
    proc = kernel / 'proc/proc_pdp6.s'
    s = proc.read_text()
    anchor = '''        ; This subset is non-sleeping: MEMFS direct XIP dispatch,
        ; validated MM extent deletion, and swap backing bitmap detach.
        move    1,12
        move    2,10
        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done
proc_finish_prevm_fail_v1081:'''
    replacement = '''        ; This subset is non-sleeping: MEMFS direct XIP dispatch,
        ; validated MM extent deletion, and swap backing bitmap detach.
        ; v1800b scratch: pin only PID3's real physical VM owner.
        caie    10,3
        jrst    k04_prevm_real_v1800b
        skipn   k04_prevm_done_v1800b
        jrst    k04_prevm_active_v1800b
        jrst    k04_prevm_real_v1800b
k04_prevm_active_v1800b:
        skipn   5,k04_prevm_base_v1800b
        jrst    k04_prevm_first_v1800b
        move    4,1(12)
        hrrz    4,4
        came    4,5
        jrst    k04_prevm_bad_v1800b
        aos     5,k04_prevm_calls_v1800b
        caige   5,020                 ; sixteen true MM attempts
        jrst    k04_prevm_real_v1800b
        move    1,4
        pushj   17,mm_unpin
        jumpn   1,k04_prevm_bad_v1800b
        setzm   k04_prevm_base_v1800b
        setom   k04_prevm_done_v1800b
        jrst    k04_prevm_real_v1800b
k04_prevm_first_v1800b:
        move    1,1(12)
        hrrz    1,1
        jumpe   1,k04_prevm_bad_v1800b
        push    17,1
        pushj   17,mm_pin
        jumpn   1,k04_prevm_pin_bad_v1800b
        pop     17,4
        movem   4,k04_prevm_base_v1800b
        movei   5,1
        movem   5,k04_prevm_calls_v1800b
        jrst    k04_prevm_real_v1800b
k04_prevm_pin_bad_v1800b:
        pop     17,4
k04_prevm_bad_v1800b:
        aos     k04_prevm_bad_count_v1800b
        seto    1,
        jrst    proc_finish_prevm_fail_v1081
k04_prevm_real_v1800b:
        move    1,12
        move    2,10
        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done
proc_finish_prevm_fail_v1081:'''
    s = one(s, anchor, replacement)
    s = one(s, '''proc_finish_orphan_free_v1768:
        setzm   (12)''', '''proc_finish_orphan_free_v1768:
        ; Count only PID4's actual no-eligible-parent FREE decision.
        caie    10,4
        jrst    k04_orphan_free_real_v1800b
        aos     k04_orphan_free_v1800b
        caie    13,3                  ; original parent was PID3
        aos     k04_orphan_bad_v1800b
        skipn   k04_prevm_base_v1800b ; PID3 held an actual VM pin
        aos     k04_orphan_bad_v1800b
        skipn   k04_sync_refused_v1800b ; PID1 refused real FD3 SYNC
        aos     k04_orphan_bad_v1800b
        skipn   k04_sync_delegated_v1800b ; no premature FILE release
        jrst    k04_orphan_free_real_v1800b
        aos     k04_orphan_bad_v1800b
k04_orphan_free_real_v1800b:
        setzm   (12)''')
    s = one(s, '''proc_finish_zombie:
        move    1,14''', '''proc_finish_zombie:
        ; Any PID4 ZOMB violates the dual-ineligible expectation.
        caie    10,4
        jrst    k04_orphan_zombie_real_v1800b
        aos     k04_orphan_zombie_v1800b
k04_orphan_zombie_real_v1800b:
        move    1,14''')
    s += '''
; v1800b scratch physical owner and adoption witnesses.
        .bss
        .globl  k04_sync_refused_v1800b
        .globl  k04_sync_delegated_v1800b
        .globl  k04_prevm_base_v1800b
k04_prevm_base_v1800b:       .block 1
        .globl  k04_prevm_calls_v1800b
k04_prevm_calls_v1800b:      .block 1
        .globl  k04_prevm_done_v1800b
k04_prevm_done_v1800b:       .block 1
        .globl  k04_prevm_bad_count_v1800b
k04_prevm_bad_count_v1800b:  .block 1
        .globl  k04_orphan_free_v1800b
k04_orphan_free_v1800b:      .block 1
        .globl  k04_orphan_zombie_v1800b
k04_orphan_zombie_v1800b:    .block 1
        .globl  k04_orphan_bad_v1800b
k04_orphan_bad_v1800b:       .block 1
'''
    proc.write_text(s)

    vfs = kernel / 'fs/vfs.s'
    s = vfs.read_text()
    s = one(s, '''vfs_sync:
        ldb     7,[POINT 6,1,5]''', '''vfs_sync:
        ; v1800b: only PID1's actual FD3 regular-file vnode.
        .globl  proc_current_slot
        .globl  k04_orphan_free_v1800b
        push    17,2
        move    2,proc_current_slot
        caie    2,1
        jrst    k04_sync_real_v1800b
        move    2,file_table
        jumpe   2,k04_sync_real_v1800b
        move    2,006(2)              ; exact FD3 packed vnode
        jumpe   2,k04_sync_real_v1800b
        tlz     2,700070             ; canonical vnode identity
        came    1,2
        jrst    k04_sync_real_v1800b
        aos     k04_sync_calls_v1800b
        move    2,file_table
        move    2,-2(2)
        trnn    2,4                  ; only real fatal private stack
        aos     k04_sync_bad_v1800b
        skipn   k04_orphan_free_v1800b
        jrst    k04_sync_guard_v1800b
k04_sync_delegate_v1800b:
        aos     k04_sync_delegated_v1800b
        jrst    k04_sync_real_v1800b
k04_sync_guard_v1800b:
        ; Bounded emergency release even on a broken orphan path.
        ; Such a run fails the orphan witness, never becomes PASS.
        move    2,k04_sync_calls_v1800b
        caile   2,020
        jrst    k04_sync_delegate_v1800b
k04_sync_refuse_v1800b:
        aos     k04_sync_refused_v1800b
        pop     17,2
        movni   1,5
        popj    17,
k04_sync_real_v1800b:
        pop     17,2
        ldb     7,[POINT 6,1,5]''')
    s += '''
; v1800b scratch-only actual FILE close/SYNC refusal witnesses.
        .bss
        .globl  k04_sync_calls_v1800b
k04_sync_calls_v1800b:       .block 1
        .globl  k04_sync_refused_v1800b
k04_sync_refused_v1800b:     .block 1
        .globl  k04_sync_delegated_v1800b
k04_sync_delegated_v1800b:   .block 1
        .globl  k04_sync_bad_v1800b
k04_sync_bad_v1800b:         .block 1
'''
    vfs.write_text(s)
    print('v1800b PID1 real FD3 fatal FILE refusal and PID3 MM pin installed')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fixture-v1800b.py COPIED_KERNEL')
    install(Path(sys.argv[1]))
