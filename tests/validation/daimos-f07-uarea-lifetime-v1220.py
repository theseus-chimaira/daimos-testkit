#!/usr/bin/env python3
"""Trace physical PID 1 u-area removal during pressure (disposable guest).

Capture the complete descriptor before and after the real free. The
original MM owner/type/pin checks and return codes are untouched.
"""

from pathlib import Path
import sys


FIELDS = ('calls', 'pid1_calls', 'owner', 'before', 'after',
          'sched', 'current', 'released')


def inject(root):
    path = root / 'proc/proc_pdp6.s'
    source = path.read_text()
    anchor = 'proc_uarea_release:\n'
    if source.count(anchor) != 1:
        raise ValueError('v1220: u-area release entry moved')
    source = source.replace(anchor, '''proc_uarea_release:
        aos     daimos_f07u_calls_v1220
        movem   1,daimos_f07u_owner_v1220
        caie    1,1
        jrst    daimos_f07u_entry_done_v1220
        aos     daimos_f07u_pid1_calls_v1220
        move    7,(2)
        movem   7,daimos_f07u_before_v1220
        move    7,2(2)
        movem   7,daimos_f07u_sched_v1220
        move    7,proc_current_slot
        movem   7,daimos_f07u_current_v1220
daimos_f07u_entry_done_v1220:
''', 1)
    anchor = ('        movem   1,(10)\n'
              '        pop     17,10\n'
              '        jrst    kret_zero\n'
              'proc_uarea_release_fail:')
    if source.count(anchor) != 1:
        raise ValueError('v1220: u-area commit moved')
    source = source.replace(anchor, '''        movem   1,(10)
        ; v1220: this is the only successful flag/base clear.
        move    7,daimos_f07u_owner_v1220
        caie    7,1
        jrst    daimos_f07u_clear_done_v1220
        aos     daimos_f07u_released_v1220
        movem   1,daimos_f07u_after_v1220
daimos_f07u_clear_done_v1220:
        pop     17,10
        jrst    kret_zero
proc_uarea_release_fail:''', 1)
    source += '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07u_%s_v1220' % field
        source += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1220 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
