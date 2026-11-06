#!/usr/bin/env python3
"""Snapshot slot-0 I/O ownership at entry to the native event wait.

Only the disposable copied kernel is modified. The original PUSHJ return,
AC0, stack pointer and both storage request queues remain unmodified.
"""

from pathlib import Path
import sys


FIELDS = (
    'calls', 'event', 'event_value', 'sp', 'caller',
    'drm_active', 'drm_pending', 'storage_state', 'storage_iowd',
    'sched_cursor', 'current_slot', 'timer_clock', 'swap_backoff',
    'pi_state', 'saved_ac0',
)


def inject(root):
    path = root / 'proc/proc_pdp6.s'
    source = path.read_text()
    original = '''proc_wait_boot:
        skipn   (1)
        jrst    proc_wait_boot
        jrst    kret_zero
'''
    replacement = '''proc_wait_boot:
        aos     daimos_f07w_calls_v1250
        movem   0,daimos_f07w_saved_ac0_v1250
        movem   1,daimos_f07w_event_v1250
        movem   17,daimos_f07w_sp_v1250
        move    0,(17)
        movem   0,daimos_f07w_caller_v1250
        move    0,(1)
        movem   0,daimos_f07w_event_value_v1250
        move    0,drm236_active_request
        movem   0,daimos_f07w_drm_active_v1250
        move    0,drm236_pending_request
        movem   0,daimos_f07w_drm_pending_v1250
        move    0,storage_state
        movem   0,daimos_f07w_storage_state_v1250
        move    0,storage_iowd
        movem   0,daimos_f07w_storage_iowd_v1250
        move    0,proc_sched_cursor
        movem   0,daimos_f07w_sched_cursor_v1250
        move    0,proc_current_slot
        movem   0,daimos_f07w_current_slot_v1250
        move    0,proc_timer_clock
        movem   0,daimos_f07w_timer_clock_v1250
        move    0,proc_swap_pressure_ticks
        movem   0,daimos_f07w_swap_backoff_v1250
        coni    0004,0
        movem   0,daimos_f07w_pi_state_v1250
        move    0,daimos_f07w_saved_ac0_v1250
daimos_f07w_poll_v1250:
        skipn   (1)
        jrst    daimos_f07w_poll_v1250
        jrst    kret_zero
'''
    if source.count(original) != 1:
        raise ValueError('v1250: process event-wait ABI changed')
    source = source.replace(original, replacement, 1)
    source = '''        .globl drm236_active_request
        .globl drm236_pending_request
        .globl storage_state
        .globl storage_iowd
''' + source
    for name in FIELDS:
        source = '        .globl daimos_f07w_%s_v1250\n' % name + source
    source += '\n        .bss\n'
    for name in FIELDS:
        symbol = 'daimos_f07w_%s_v1250' % name
        source += '%s: .block 1\n' % symbol
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1250 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
