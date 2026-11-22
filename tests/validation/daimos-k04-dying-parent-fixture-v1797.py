#!/usr/bin/env python3
"""Hold a real PREVM VM pin while the child's parent is terminated.

Transforms the validated generated v1781 single-PREVM scratch fixture;
only copied assembly may be supplied, never production source.
"""
from pathlib import Path
import sys


def prepare_v1797(asm_dir):
    if asm_dir.name != 'kcore-asm' or 'v1797' not in str(asm_dir):
        raise ValueError('expected v1797 generated scratch kcore-asm')
    p = asm_dir / 'proc_pdp6.s'
    s = p.read_text()
    if 'k04_prevm_active_v1781:' not in s:
        raise ValueError('source is not the accepted v1781 fixture')
    old = '''        aos     5,k04_prevm_calls_v1781
        caige   5,5                   ; five real VM attempts
'''
    if s.count(old) != 1:
        # Some v1781 source snapshots retain the shorter inline comment.
        old = '''        aos     5,k04_prevm_calls_v1781
        caige   5,5
'''
    if s.count(old) != 1:
        raise ValueError('unrecognized PREVM release threshold')
    new = old.replace('caige   5,5', 'caige   5,014')
    s = s.replace(old, new, 1)
    s = s.replace('v1781 disposable PREVM', 'v1797 disposable PREVM')
    s = s.replace('v1781', 'v1797')
    if 'v1781' in s or 'k04_prevm_calls_v1797' not in s:
        raise ValueError('renaming incomplete')
    if 'caige   5,014' not in s:
        raise ValueError('12-attempt release missing')
    if s.count('iorm    5,proc_finish_last_tick_v881 ; pending; no extra RAM word\n'
               '        popj    17,') != 1:
        raise ValueError('missing original pending helper POPJ')
    p.write_text(s)
    print('v1797: PID5 PREVM physical MM pin held for 12 real VM calls')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fixture-v1797.py SCRATCH_KCORE_ASM')
    prepare_v1797(Path(sys.argv[1]))
