#!/usr/bin/env python3
"""Instrument two real slot-0 TERM deliveries in a disposable F07 guest.

v1495 already injects a one-bit BACKSTORE fault. This extension records
the exact foreign-event branch and the process owner immediately before
and after event delivery. It never changes production repository files.
"""

from pathlib import Path
import runpy
import sys

BASE = Path(__file__).with_name('daimos-swap-refusal-instrument-v1495.py')
ARRAYS = ('pre_meta', 'pre_vm', 'pre_sched', 'pre_pc', 'pre_fdctl',
          'pre_finalize', 'event_result', 'post_meta', 'post_vm',
          'post_sched', 'post_fdctl', 'post_finalize')
COUNTERS = ('events', 'active', 'overflow', 'foreign', 'deferred',
            'busy', 'finish', 'prevm_refused', 'close_refused')


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise AssertionError('v1499 production anchor drift: ' + repr(old))
    return source.replace(old, new, 1)


def instrument(kernel):
    runpy.run_path(str(BASE))['inject'](kernel)
    swap_path = kernel / 'proc/proc_swap_pdp6.s'
    proc_path = kernel / 'proc/proc_pdp6.s'
    data_path = kernel / 'storage/backstore_entry_v484.s'
    swap = swap_path.read_text()
    proc = proc_path.read_text()
    data = data_path.read_text()

    # Only AC4..AC7 are used by these observations. AC1 and AC2 retain
    # the authentic slot and TERM parameters for proc_event_apply.
    before = '''        movei   2,SYS_EVENT_TERM
        pushj   17,proc_event_apply
        aos     daimos_v1495_event_returned
'''
    after = '''        movei   2,SYS_EVENT_TERM
        move    4,daimos_v1499_events
        caige   4,2
        jrst    daimos_v1499_pre_capture
        aos     daimos_v1499_overflow
        jrst    daimos_v1499_call
daimos_v1499_pre_capture:
        move    5,(17)
        lsh     5,1
        add     5,(17)
        add     5,proc_table
        move    6,(5)
        movem   6,daimos_v1499_pre_meta(4)
        move    6,1(5)
        movem   6,daimos_v1499_pre_vm(4)
        move    6,2(5)
        movem   6,daimos_v1499_pre_sched(4)
        hlrz    6,(5)
        jumpe   6,daimos_v1499_pre_bad
        move    7,020(6)
        movem   7,daimos_v1499_pre_pc(4)
        move    7,024(6)
        movem   7,daimos_v1499_pre_fdctl(4)
        move    7,067(6)
        movem   7,daimos_v1499_pre_finalize(4)
        jrst    daimos_v1499_pre_done
daimos_v1499_pre_bad:
        aos     daimos_v1499_overflow
daimos_v1499_pre_done:
        aos     daimos_v1499_events
daimos_v1499_call:
        setom   daimos_v1499_active
        pushj   17,proc_event_apply
        setzm   daimos_v1499_active
        move    4,daimos_v1499_events
        jumpe   4,daimos_v1499_post_done
        subi    4,1
        caige   4,2
        jrst    daimos_v1499_post_capture
        jrst    daimos_v1499_post_done
daimos_v1499_post_capture:
        movem   1,daimos_v1499_event_result(4)
        move    5,(17)
        lsh     5,1
        add     5,(17)
        add     5,proc_table
        move    6,(5)
        movem   6,daimos_v1499_post_meta(4)
        move    6,1(5)
        movem   6,daimos_v1499_post_vm(4)
        move    6,2(5)
        movem   6,daimos_v1499_post_sched(4)
        hlrz    6,(5)
        jumpe   6,daimos_v1499_post_done
        move    7,024(6)
        movem   7,daimos_v1499_post_fdctl(4)
        move    7,067(6)
        movem   7,daimos_v1499_post_finalize(4)
daimos_v1499_post_done:
        aos     daimos_v1495_event_returned
'''
    swap = replace_once(swap, before, after)

    # These are stage witnesses only while the slot-0 swap failure
    # invokes real proc_event_apply. All other process events remain
    # unmodified and uncounted. AOS on memory does not touch AC state.
    for label, counter in (
            ('proc_event_fatal_other:', 'foreign'),
            ('proc_event_fatal_other_defer_term_v926:', 'deferred'),
            ('proc_event_fatal_close_busy_v879:', 'busy'),
            ('proc_event_fatal_other_close_fail_v867:', 'close_refused'),
            ('proc_finish_slot:', 'finish'),
            ('proc_finish_prevm_fail_v1081:', 'prevm_refused')):
        proc = replace_once(proc, label + '\n', label + '\n'
            '        skipe   daimos_v1499_active\n'
            '        aos     daimos_v1499_' + counter + '\n')

    data += '\n; v1499 DISPOSABLE TWO-EVENT TRACE; no production RAM.\n'
    data += '        .bss\n'
    for name in COUNTERS:
        symbol = 'daimos_v1499_' + name
        data += '        .globl %s\n%s: .block 1\n' % (symbol, symbol)
    for name in ARRAYS:
        symbol = 'daimos_v1499_' + name
        data += '        .globl %s\n%s: .block 2\n' % (symbol, symbol)
    swap_path.write_text(swap)
    proc_path.write_text(proc)
    data_path.write_text(data)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1499.py DISPOSABLE_KERNEL')
    instrument(Path(sys.argv[1]))
