#!/usr/bin/env python3
"""Strict F07 faulted-guest witness for safe deferred TERM ownership.

The v1494 injector previously asserted PREVM+TRANSITION immediately
after a failed swap-in, although production clears TRANSITION on
rollback and may defer TERM until the sleeping owner can resume.
v1713 retains the same physical one-bit fault and exact three frees,
but asserts the real disk-owner, pending-TERM and retry boundaries.
No production source is changed by this test-only injection.
"""

from pathlib import Path
import runpy
import sys


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise AssertionError('v1713 production witness anchor drift: ' + repr(old))
    return text.replace(old, new, 1)


def inject(kernel):
    tests = Path(__file__).resolve().parent
    runpy.run_path(str(tests / 'daimos-swap-refusal-fullguest-v1494.py'))[
        'inject'](kernel)
    swap_path = kernel / 'proc/proc_swap_pdp6.s'
    back_path = kernel / 'storage/backstore.s'
    swap = swap_path.read_text()
    back = back_path.read_text()

    # The actual restored VM has already been unpinned and freed by
    # proc_swap_in_free_fail. Its DISK record must remain authoritative,
    # with no private-stack PREVM finalizer published by a foreign TERM.
    # The user still owns a private continuation and must receive the
    # deferred TERM when the original image is safely restored.
    old = '''        trne    6,PROC_TRANSITION_RH
        jrst    daimos_v1494_term_transition
        aos     daimos_v1494_errors
daimos_v1494_term_transition:
        hlrz    6,6
        move    6,067(6)
        tlne    6,0100000              ; PREVM after refused detach
        jrst    daimos_v1494_term_marked
        aos     daimos_v1494_errors
daimos_v1494_term_marked:
'''
    new = '''        ; Failed restore rolled back the provisional physical extent.
        ; A still-locked TRANSITION would strand this DISK process.
        trnn    6,PROC_TRANSITION_RH
        jrst    daimos_v1494_term_transition
        aos     daimos_v1494_errors
daimos_v1494_term_transition:
        hlrz    6,6
        ; TERM=1 is represented by LH bit 04 in the FD control word.
        ; Fatal-other must queue it for the owner with a live kernel
        ; continuation, rather than destroying that private stack.
        move    5,024(6)
        tlne    5,04
        jrst    daimos_v1713_term_queued
        aos     daimos_v1494_errors
daimos_v1713_term_queued:
        move    6,067(6)
        tlnn    6,0100000              ; no PREVM during deferred TERM
        jrst    daimos_v1494_term_marked
        aos     daimos_v1494_errors
daimos_v1494_term_marked:
'''
    swap = replace_once(swap, old, new)

    # On the third free the newly restored candidate is in TRANSITION;
    # its original DISK record has not yet been retired. The deferred
    # TERM must still be pending, and PREVM must NOT be published.
    old = '''        move    4,067(5)
        tlne    4,0100000
        jrst    daimos_v1494_retry_marked
        aos     daimos_v1494_errors
daimos_v1494_retry_marked:
'''
    new = '''        move    4,067(5)
        tlnn    4,0100000
        jrst    daimos_v1494_retry_marked
        aos     daimos_v1494_errors
daimos_v1494_retry_marked:
        move    4,024(5)
        tlne    4,04                  ; deferred TERM still owned
        jrst    daimos_v1713_retry_pending
        aos     daimos_v1494_errors
daimos_v1713_retry_pending:
'''
    back = replace_once(back, old, new)

    # Keep the injected code's explanation consistent with its actual
    # source-linked state checks. This is a fresh restore attempt, not
    # a PREVM finalizer; the original disk run remains authoritative.
    back = replace_once(back,
        '''        ; The real fatal event's FIRST detach must have failed and
        ; registered PREVM before an idle finalizer can retry.
''',
        '''        ; The first two exact DISK-run frees refused. This third
        ; free belongs to a new, still-locked restore transaction, not
        ; to a PREVM finalizer; deferred TERM remains owned.
''')

    swap_path.write_text(swap)
    back_path.write_text(back)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1713.py DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
