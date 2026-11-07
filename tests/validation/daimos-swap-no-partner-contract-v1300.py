#!/usr/bin/env python3
"""Check the current PDP-6 swap-in pressure/no-partner safety contract.

This is a source/assembler regression, not proof that the scheduler
eventually makes progress with no resident exchange candidate.  The
full 256K guest remains required for that liveness question.
"""

from pathlib import Path
import sys


def region(source, start, end):
    a = source.index('\n' + start + ':\n')
    b = source.index('\n' + end + ':\n', a + 1)
    return source[a:b]


def verify(source):
    service = region(source, 'proc_swap_service_pressure',
                     'proc_swap_service_failed')
    no_pair = region(source, 'proc_swap_service_no_pair_v834',
                     'proc_swap_service_failed')
    failed = region(source, 'proc_swap_service_failed',
                    'proc_swap_service_pop_clear')
    alloc = region(source, 'proc_swap_in_alloc_status',
                   'proc_swap_in_restore')

    required = (
        'jumpg   1,proc_swap_service_pressure',
        'jumpn   1,proc_swap_service_failed',
        'proc_swap_service_pressure:\n',
        'move    2,-1(17)',
        'pushj   17,proc_swap_exchange_pair_v826',
        'jumpn   1,proc_swap_service_next_v834',
        'pushj   17,proc_swap_exchange_execute_v832',
        'jrst    proc_swap_service_candidate_v834',
        'proc_swap_service_no_pair_v834:\n'
        '        pop     17,2',
        'proc_swap_service_cooldown_v833:\n',
        '        movei   1,0100\n'
        '        movem   1,proc_swap_pressure_ticks\n'
        '        pop     17,1\n'
        '        movem   1,proc_sched_cursor\n'
        '        jrst    kret_zero',
        'proc_swap_service_failed:\n'
        '        move    1,(17)\n'
        '        movem   1,proc_sched_cursor\n'
        '        movei   2,SYS_EVENT_TERM\n'
        '        pushj   17,proc_event_apply',
        'proc_swap_in_pressure:\n        movei   1,1',
    )
    if not all(token in source for token in required):
        raise ValueError('swap-in branch, candidate scan or cooldown changed')

    # A failed candidate scan must neither terminate the owner nor
    # release or publish its disk-backed image.  It only defers retry.
    forbidden = ('proc_event_apply', 'backstore_free', 'mm_free',
                 'proc_storage_publish_v30', 'proc_swap_out')
    if any(token in no_pair for token in forbidden):
        raise ValueError('no-pair path destroys process ownership')
    if 'proc_event_apply' not in failed or \
            'proc_event_apply' in no_pair:
        raise ValueError('fatal and pressure results are confused')
    if 'jumpn   7,proc_swap_in_pressure' not in alloc:
        raise ValueError('retryable MM result converted into fatal')
    if source.count('proc_swap_service_cooldown_v833:\n') != 1:
        raise ValueError('ambiguous cooldown entry')
    # Check the corresponding reschedule gate, not just the service.
    return service


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1300 DAIMOS_REPO')
    root = Path(sys.argv[1]) / 'system/kernel'
    source = (root / 'proc/proc_swap_pdp6.s').read_text()
    sched = (root / 'proc/proc_pdp6.s').read_text()
    verify(source)
    if 'sos     proc_swap_pressure_ticks' not in sched or \
            sched.count('skipn   proc_swap_pressure_ticks') < 2:
        raise AssertionError('missing scheduler pressure cooldown gate')

    mutants = (
        ('wrong-result', 'jumpg   1,proc_swap_service_pressure',
         'jumpn   1,proc_swap_service_pressure'),
        ('no-candidate-advance', 'jrst    proc_swap_service_candidate_v834',
         'jrst    proc_swap_service_no_pair_v834'),
        ('no-delay', 'movei   1,0100', 'setz    1,'),
        ('lost-cursor', 'movem   1,proc_sched_cursor\n'
         '        jrst    kret_zero', 'setzm   proc_sched_cursor\n'
         '        jrst    kret_zero'),
        ('pressure-kills', 'jrst    kret_zero\n\nproc_swap_service_failed:',
         'jrst    proc_swap_service_failed\n\nproc_swap_service_failed:'),
        ('no-pressure-value', 'proc_swap_in_pressure:\n        movei   1,1',
         'proc_swap_in_pressure:\n        seto    1,'),
    )
    for label, old, replacement in mutants:
        if old not in source:
            raise AssertionError('missing mutation anchor: ' + label)
        changed = source.replace(old, replacement, 1)
        try:
            verify(changed)
        except ValueError:
            continue
        raise AssertionError('unsafe mutation accepted: ' + label)
    print('v1300: native source no-partner ownership/cooldown, six '
          'negative mutations and scheduler gate PASS')


if __name__ == '__main__':
    main()
