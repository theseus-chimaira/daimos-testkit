#!/usr/bin/env python3
"""Expose live provider contention for a disposable F07 guest only.

The three read-only BRK sentinel queries are intercepted before VM/BRK.
Production syscall code and all ordinary BRK requests are untouched.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()
    anchor = 'native_sys_brk:\n        move    1,2\n'
    if source.count(anchor) != 1:
        raise ValueError('v1279: ambiguous BRK entry')
    hook = '''native_sys_brk:
        ; v1279 disposable 64-slot admission barrier: observe only.
        ; These reserved probes never invoke physical BRK or OOM.
        caie    2,0777764
        jrst    daimos_f07_barrier_spinner_v1279
        move    1,daimos_test_predispatch_v1150
        popj    17,
daimos_f07_barrier_spinner_v1279:
        caie    2,0777765
        jrst    daimos_f07_barrier_holder_v1279
        move    1,daimos_test_spinner_v1150
        popj    17,
daimos_f07_barrier_holder_v1279:
        caie    2,0777766
        jrst    daimos_f07_barrier_regular_v1279
        move    1,daimos_test_holder_enter_v1150
        popj    17,
daimos_f07_barrier_regular_v1279:
        move    1,2
'''
    source = ('''        .globl daimos_test_predispatch_v1150
        .globl daimos_test_spinner_v1150
        .globl daimos_test_holder_enter_v1150
''' + source.replace(anchor, hook, 1))
    path.write_text(source)


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1279 DISPOSABLE_KERNEL_ROOT')
    inject(Path(sys.argv[1]))


if __name__ == '__main__':
    main()
