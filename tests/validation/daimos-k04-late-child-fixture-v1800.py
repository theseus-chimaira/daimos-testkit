#!/usr/bin/env python3
"""Pin real PID2 PREVM VM during a later PID3 terminal publication.

Only modifies a disposable v1800 copy of proc_pdp6.s. The original
vm_space_destroy, mm_pin and mm_unpin remain the physical providers.
"""
from pathlib import Path
import sys


def install(kernel):
    if kernel.name != 'kernel' or 'v1800' not in str(kernel):
        raise ValueError('expected disposable v1800 kernel')
    path = kernel / 'proc/proc_pdp6.s'
    source = path.read_text()
    anchor = '''        ; This subset is non-sleeping: MEMFS direct XIP dispatch,
        ; validated MM extent deletion, and swap backing bitmap detach.
        move    1,12
        move    2,10
        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done
proc_finish_prevm_fail_v1081:'''
    replacement = '''        ; This subset is non-sleeping: MEMFS direct XIP dispatch,
        ; validated MM extent deletion, and swap backing bitmap detach.
        ; v1800-A: only PID2 owns this physical PREVM pin.
        caie    10,2
        jrst    k04_prevm_real_v1800
        skipn   k04_prevm_done_v1800
        jrst    k04_prevm_active_v1800
        jrst    k04_prevm_real_v1800
k04_prevm_active_v1800:
        skipn   5,k04_prevm_base_v1800
        jrst    k04_prevm_first_v1800
        move    4,1(12)
        hrrz    4,4
        came    4,5
        jrst    k04_prevm_bad_v1800
        aos     5,k04_prevm_calls_v1800
        caige   5,020
        jrst    k04_prevm_real_v1800
        move    1,4
        pushj   17,mm_unpin
        jumpn   1,k04_prevm_bad_v1800
        setzm   k04_prevm_base_v1800
        setom   k04_prevm_done_v1800
        jrst    k04_prevm_real_v1800
k04_prevm_first_v1800:
        move    1,1(12)
        hrrz    1,1
        jumpe   1,k04_prevm_bad_v1800
        push    17,1
        pushj   17,mm_pin
        jumpn   1,k04_prevm_pin_bad_v1800
        pop     17,4
        movem   4,k04_prevm_base_v1800
        movei   5,1
        movem   5,k04_prevm_calls_v1800
        jrst    k04_prevm_real_v1800
k04_prevm_pin_bad_v1800:
        pop     17,4
k04_prevm_bad_v1800:
        seto    1,
        jrst    proc_finish_prevm_fail_v1081
k04_prevm_real_v1800:
        move    1,12
        move    2,10
        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done
proc_finish_prevm_fail_v1081:'''
    if source.count(anchor) != 1:
        raise ValueError('production PREVM anchor changed')
    source = source.replace(anchor, replacement, 1)
    source += '''
; v1800-A scratch-only physical PREVM MM witnesses.
        .bss
        .globl  k04_prevm_base_v1800
k04_prevm_base_v1800:       .block 1
        .globl  k04_prevm_calls_v1800
k04_prevm_calls_v1800:      .block 1
        .globl  k04_prevm_done_v1800
k04_prevm_done_v1800:       .block 1
'''
    path.write_text(source)
    print('v1800-A PID2 real PREVM MM pin fixture installed')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fixture-v1800.py COPIED_KERNEL')
    install(Path(sys.argv[1]))
