#!/usr/bin/env python3
"""Extra, read-only witnesses for disposable v1494 BACKSTORE full guest.

Run v1494's existing one-bit fault injection first. Separate counters
distinguish actual service/event entry, the witness's stack argument,
and the two independent PREVM assertions. No production files change.
"""

from pathlib import Path
import runpy
import sys


NAMES = (
    'failed_entry', 'service_slot', 'event_returned',
    'witness_enter', 'witness_slot', 'witness_top', 'witness_below',
    'term_unlock_error', 'term_mark_error',
    'retry_unlock_error', 'retry_mark_error',
    'retry_descriptor', 'retry_marker',
)


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise AssertionError('v1495 source anchor missing: ' + repr(old))
    return text.replace(old, new, 1)


def inject(kernel):
    old = Path(__file__).with_name('daimos-swap-refusal-fullguest-v1494.py')
    runpy.run_path(str(old))['inject'](kernel)

    swap_path = kernel / 'proc/proc_swap_pdp6.s'
    store_path = kernel / 'storage/backstore.s'
    data_path = kernel / 'storage/backstore_entry_v484.s'
    swap = swap_path.read_text()
    store = store_path.read_text()
    data = data_path.read_text()

    swap = replace_once(swap,
        'proc_swap_service_failed:\n        move    1,(17)\n',
        'proc_swap_service_failed:\n'
        '        aos     daimos_v1495_failed_entry\n'
        '        move    1,(17)\n'
        '        movem   1,daimos_v1495_service_slot\n')
    swap = replace_once(swap,
        '        pushj   17,proc_event_apply\n'
        '        pushj   17,daimos_v1494_term_witness\n',
        '        pushj   17,proc_event_apply\n'
        '        aos     daimos_v1495_event_returned\n'
        '        pushj   17,daimos_v1494_term_witness\n')
    # The v1494 committed fixture used -3(17), while the local
    # corrective experiment used -4(17). The diagnostic must work from
    # either exact version and explicitly normalize to the corrected
    # stack address without silently accepting an arbitrary source edit.
    stack_prefix = ('daimos_v1494_term_witness:\n'
                    '        push    17,4\n'
                    '        push    17,5\n'
                    '        push    17,6\n')
    old_stack = stack_prefix + (
        '        move    4,-3(17)               ; service\'s pending slot\n')
    new_stack = stack_prefix + (
        '        ; PUSHJ saved the return PC above the service\'s pending slot;\n'
        '        ; three additional PUSH instructions put that slot at -4(17).\n'
        '        move    4,-4(17)               ; service\'s pending slot\n')
    if swap.count(new_stack) == 1 and swap.count(old_stack) == 0:
        before = new_stack
    elif swap.count(old_stack) == 1 and swap.count(new_stack) == 0:
        before = old_stack
    else:
        raise AssertionError('v1495: unexpected v1494 TERM stack witness')
    swap = replace_once(swap, before,
        'daimos_v1494_term_witness:\n'
        '        aos     daimos_v1495_witness_enter\n'
        '        push    17,4\n'
        '        push    17,5\n'
        '        push    17,6\n'
        '        move    4,-3(17)\n'
        '        movem   4,daimos_v1495_witness_top\n'
        '        move    4,-5(17)\n'
        '        movem   4,daimos_v1495_witness_below\n'
        '        move    4,-4(17)\n'
        '        movem   4,daimos_v1495_witness_slot\n')
    swap = replace_once(swap,
        '        trne    6,PROC_TRANSITION_RH\n'
        '        jrst    daimos_v1494_term_transition\n'
        '        aos     daimos_v1494_errors\n',
        '        trne    6,PROC_TRANSITION_RH\n'
        '        jrst    daimos_v1494_term_transition\n'
        '        aos     daimos_v1495_term_unlock_error\n'
        '        aos     daimos_v1494_errors\n')
    swap = replace_once(swap,
        '        tlne    6,0100000              ; PREVM after refused detach\n'
        '        jrst    daimos_v1494_term_marked\n'
        '        aos     daimos_v1494_errors\n',
        '        tlne    6,0100000              ; PREVM after refused detach\n'
        '        jrst    daimos_v1494_term_marked\n'
        '        aos     daimos_v1495_term_mark_error\n'
        '        aos     daimos_v1494_errors\n')

    store = replace_once(store,
        '        move    4,(5)\n'
        '        trne    4,0200000\n'
        '        jrst    daimos_v1494_retry_locked\n'
        '        aos     daimos_v1494_errors\n',
        '        move    4,(5)\n'
        '        movem   4,daimos_v1495_retry_descriptor\n'
        '        trne    4,0200000\n'
        '        jrst    daimos_v1494_retry_locked\n'
        '        aos     daimos_v1495_retry_unlock_error\n'
        '        aos     daimos_v1494_errors\n')
    store = replace_once(store,
        '        move    4,067(5)\n'
        '        tlne    4,0100000\n'
        '        jrst    daimos_v1494_retry_marked\n'
        '        aos     daimos_v1494_errors\n',
        '        move    4,067(5)\n'
        '        movem   4,daimos_v1495_retry_marker\n'
        '        tlne    4,0100000\n'
        '        jrst    daimos_v1494_retry_marked\n'
        '        aos     daimos_v1495_retry_mark_error\n'
        '        aos     daimos_v1494_errors\n')

    data += '\n; v1495 DISPOSABLE DIAGNOSTICS: no production state.\n'
    data += '        .bss\n'
    for name in NAMES:
        label = 'daimos_v1495_' + name
        data += '        .globl %s\n%s: .block 1\n' % (label, label)
    swap_path.write_text(swap)
    store_path.write_text(store)
    data_path.write_text(data)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1495.py DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
