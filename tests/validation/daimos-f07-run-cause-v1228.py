#!/usr/bin/env python3
"""Disposable RUN admission-stage and exact MM result diagnostic.

Capture only the last failed RUN's stage, typed result and claimed
child slot. No user ABI change, extra allocation, or scheduler state.
"""

from pathlib import Path
import sys


NAMES = ('stage', 'result', 'slot', 'count')


def once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('v1228: source contract changed: ' + old[:65])
    return source.replace(old, new, 1)


def inject(kernel):
    path = kernel / 'proc/proc_run.s'
    source = path.read_text()
    source = once(source, 'proc_run_block:\n', '''proc_run_block:
        aos     daimos_f07r_count_v1228
        setzm   daimos_f07r_stage_v1228
        setzm   daimos_f07r_result_v1228
''')
    source = once(source,
                  '        jumpge  1,proc_run_exec_ok\n'
                  '        ; All loader errors discard the claimed child slot identically.\n'
                  '        jrst    proc_run_claimed_bad\n',
                  '''        jumpge  1,proc_run_exec_ok
        movem   1,daimos_f07r_result_v1228
        movei   7,1                 ; EXEC image/VM loader failed
        movem   7,daimos_f07r_stage_v1228
        jrst    proc_run_claimed_bad
''')
    source = once(source,
                  '        sub     17,kconst_3_3\n'
                  '        jumpn   1,proc_run_mm_bad\n',
                  '''        sub     17,kconst_3_3
        movem   1,daimos_f07r_result_v1228
        jumpn   1,daimos_f07r_uarea_fail_v1228
''')
    source = once(source,
                  '        jumpe   014,proc_run_mm_bad\n',
                  '        jumpe   014,daimos_f07r_uarea_fail_v1228\n')
    source = once(source,
                  '        jumpn   1,proc_run_startup_failed\n',
                  '''        jumpn   1,daimos_f07r_startup_fail_v1228
''')
    source = once(source, 'proc_run_claimed_bad:\n', '''daimos_f07r_uarea_fail_v1228:
        movei   7,2                 ; U-area MM allocation
        movem   7,daimos_f07r_stage_v1228
        jrst    proc_run_claimed_bad
daimos_f07r_startup_fail_v1228:
        movem   1,daimos_f07r_result_v1228
        movei   7,3                 ; VM startup
        movem   7,daimos_f07r_stage_v1228
        jrst    proc_run_startup_failed
proc_run_claimed_bad:
        movem   012,daimos_f07r_slot_v1228
''')
    for name in NAMES:
        source = ('        .globl daimos_f07r_%s_v1228\n' % name) + source
    path.write_text(source)

    core = kernel / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for name in NAMES:
        sym = 'daimos_f07r_%s_v1228' % name
        text += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1228 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
