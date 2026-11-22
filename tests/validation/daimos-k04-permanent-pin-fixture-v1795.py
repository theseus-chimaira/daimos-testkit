#!/usr/bin/env python3
"""Turn generated v1794 PREVM-A/SIDL-B assembly into permanent-pin v1795.

Usage: python3 daimos-k04-permanent-pin-fixture-v1795.py SCRATCH_KCORE_ASM

Only generated scratch copies may be passed. Production source is untouched.
The A pin stays physically held until the guest operator invokes HALT.
"""
from pathlib import Path
import sys


def transform_v1795(folder):
    if folder.name != 'kcore-asm':
        raise ValueError('only a generated scratch kcore-asm is accepted')
    p = folder / 'proc_pdp6.s'
    q = folder / 'proc_run.s'
    s = p.read_text()
    r = q.read_text()
    if s.count('v1794') < 20 or r.count('v1794') < 1:
        raise ValueError('expected the validated v1794 scratch fixture')

    # This is a real permanent physical MM pin: do not manufacture an
    # MM_ERR_BUSY return or release A at a later attempt threshold.
    old = '''        aos     5,k04_prevm_calls_v1794
        caige   5,030                  ; 24 attempts, octal
        jrst    k04_prevm_real_v1794
        move    1,4
        pushj   17,mm_unpin
        jumpn   1,k04_prevm_bad_v1794
        setzm   k04_prevm_base_v1794
        setom   k04_prevm_done_v1794
        jrst    k04_prevm_real_v1794
'''
    new = '''        aos     5,k04_prevm_calls_v1794
        ; v1795 permanent real pin: ordinary destroy must keep refusing.
        jrst    k04_prevm_real_v1794
'''
    if s.count(old) != 1:
        raise ValueError('A release control flow does not match v1794')
    s = s.replace(old, new, 1)

    # Preserve source evidence of A's counter before B first touches MM.
    old = '''        movem   4,k04_sidl_base_v1794
        move    5,proc_finish_last_tick_v881
'''
    new = '''        movem   4,k04_sidl_base_v1794
        move    5,k04_prevm_calls_v1794
        movem   5,k04_a_calls_at_b_v1794
        move    5,proc_finish_last_tick_v881
'''
    if s.count(old) != 1:
        raise ValueError('B first pin site does not match v1794')
    s = s.replace(old, new, 1)
    s += '''\n; v1795 disposable witness of A count when B first pinned.
        .bss
        .globl  k04_a_calls_at_b_v1795
k04_a_calls_at_b_v1795:
        .block 1
'''
    # The one-word witness, the assembly symbols and the RUN injection are
    # consistently versioned, so no old fixture names can collide.
    s = s.replace('v1794', 'v1795')
    r = r.replace('v1794', 'v1795')
    if 'v1794' in s + r or 'k04_prevm_done_v1795' not in s:
        raise ValueError('incomplete fixture renaming')
    if s.count('iorm    5,proc_finish_last_tick_v881 ; pending; no extra RAM word\n'
               '        popj    17,') != 1:
        raise ValueError('mandatory helper return instruction missing')
    p.write_text(s)
    q.write_text(r)
    print('v1795 real PREVM A pin remains held; B SIDL unpins on fifth')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fixture-v1795.py SCRATCH_KCORE_ASM')
    transform_v1795(Path(sys.argv[1]))
