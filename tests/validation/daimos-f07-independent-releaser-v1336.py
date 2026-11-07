#!/usr/bin/env python3
"""Test-only, real-MM independent release after real swap cooldown.

Apply after v1327's four genuine early owner allocations. The normal
production BRK, scheduler, MM and SWAP implementations stay untouched.
Only the disposable F07 kernel gains two diagnostic BRK selectors:
slot 5 reads the real no-partner cooldown counter and, when positive,
releases the four test-owner extents and its own production MM pin.
"""

from pathlib import Path
import sys


def replace_once(source, old, new, name):
    if source.count(old) != 1:
        raise ValueError('v1336 source anchor changed: ' + name)
    return source.replace(old, new, 1)


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()

    old = '''daimos_f07_other_v1204:
        caie    2,0777763            ; exact typed release
        jrst    daimos_f07_normal_v1204
        move    0,proc_current_slot
        caie    0,1                 ; INIT only
        jrst    kret_neg1
        jrst    daimos_f07_release_v1204
daimos_f07_normal_v1204:'''
    new = '''daimos_f07_other_v1204:
        caie    2,0777763            ; real typed owner release
        jrst    daimos_f07_query_v1336
        move    0,proc_current_slot
        caie    0,5                 ; only independent spinner
        jrst    kret_neg1
        jrst    daimos_f07_release_v1204
daimos_f07_query_v1336:
        caie    2,0777767            ; read-only genuine cooldown count
        jrst    daimos_f07_normal_v1204
        move    0,proc_current_slot
        caie    0,5
        jrst    kret_neg1
        move    1,daimos_f07s_cooldown_v1209
        popj    17,
daimos_f07_normal_v1204:'''
    source = replace_once(source, old, new, 'BRK dispatch')

    # Test-owner reserve is already real; pin the actual resident
    # spinner slot 5 only after all four allocations succeeded.
    old = '''        movei   1,04
        movem   1,daimos_f07_prepared_v1204
        setz    1,
        jrst    daimos_f07_prepare_return_v1204
daimos_f07_prepare_alloc_v1204:'''
    new = '''        jrst    daimos_f07_pin_spinner_v1336
daimos_f07_pin_spinner_v1336:
        ; Slot 5 is the original independent user-mode spinner. Its
        ; descriptor is (meta, VM, sched), five times three words.
        move    6,proc_table
        hrrz    7,020(6)
        jumpe   7,daimos_f07_pin_fail_v1336
        move    1,7
        pushj   17,mm_is_pinned
        jumpn   1,daimos_f07_pin_fail_v1336
        move    1,7
        pushj   17,mm_pin
        jumpn   1,daimos_f07_pin_fail_v1336
        movem   7,daimos_f07_spinner_base_v1336
        movei   1,04
        movem   1,daimos_f07_prepared_v1204
        setz    1,
        jrst    daimos_f07_prepare_return_v1204
daimos_f07_pin_fail_v1336:
        setom   daimos_f07_error_v1204
        pushj   17,daimos_f07_cleanup_v1204
        seto    1,
        jrst    daimos_f07_prepare_return_v1204
daimos_f07_prepare_alloc_v1204:'''
    source = replace_once(source, old, new, 'spinner physical MM pin')

    # Release can occur ONLY after the actual cooldown was observed.
    # The owner releases actual MM extents and its own process pin.
    old = '''daimos_f07_release_v1204:
        move    6,daimos_f07_prepared_v1204
        caie    6,04
        jrst    daimos_f07_bad_v1204
        push    17,010
        push    17,011
        pushj   17,daimos_f07_cleanup_v1204
        pop     17,011
        pop     17,010
        popj    17,'''
    new = '''daimos_f07_release_v1204:
        move    6,daimos_f07_prepared_v1204
        caie    6,04
        jrst    daimos_f07_bad_v1204
        skipg   6,daimos_f07s_cooldown_v1209
        jrst    daimos_f07_bad_v1204
        skipn   daimos_f07_spinner_base_v1336
        jrst    daimos_f07_bad_v1204
        movem   6,daimos_f07_release_pressure_v1336
        push    17,010
        push    17,011
        pushj   17,daimos_f07_cleanup_v1204
        jumpn   1,daimos_f07_release_done_v1336
        move    1,daimos_f07_spinner_base_v1336
        pushj   17,mm_unpin
        jumpn   1,daimos_f07_release_failed_v1336
        setzm   daimos_f07_spinner_base_v1336
        aos     daimos_f07_released_v1336
        setz    1,
        jrst    daimos_f07_release_done_v1336
daimos_f07_release_failed_v1336:
        setom   daimos_f07_error_v1204
        seto    1,
daimos_f07_release_done_v1336:
        pop     17,011
        pop     17,010
        popj    17,'''
    source = replace_once(source, old, new, 'exact release and unpin')

    source = ('''        .globl mm_pin
        .globl mm_unpin
        .globl mm_is_pinned
        .globl daimos_f07s_cooldown_v1209
''' + source)
    source += '''
        .bss
        .globl daimos_f07_spinner_base_v1336
daimos_f07_spinner_base_v1336: .block 1
        .globl daimos_f07_released_v1336
daimos_f07_released_v1336: .block 1
        .globl daimos_f07_release_pressure_v1336
daimos_f07_release_pressure_v1336: .block 1
'''
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1336.py DISPOSABLE-KERNEL-ROOT')
    inject(Path(sys.argv[1]))
