#!/usr/bin/env python3
"""Inject one real BACKSTORE bitmap fault into a disposable 256K guest.

The first actual successful physical swap-in read selects the owner.
The bit stays corrupt through swap-in free and TERM/VM detach. The third
matching free (the real slot-0 PREVM retry) restores the single bit so
production finalization can complete. No production checkout is patched.
"""

from pathlib import Path
import sys


def replace_one(source, old, new):
    if source.count(old) != 1:
        raise AssertionError("v1494 production anchor drift: " + repr(old))
    return source.replace(old, new, 1)


def inject(kernel):
    swap_path = kernel / 'proc/proc_swap_pdp6.s'
    back_path = kernel / 'storage/backstore.s'
    entry_path = kernel / 'storage/backstore_entry_v484.s'
    swap = swap_path.read_text()
    back = back_path.read_text()
    entry = entry_path.read_text()

    # After the hardware read and real MM unpin, but before checked free.
    # The operation uses only scratch AC4..AC7, not the saved AC10..AC16.
    old = ('        ; The disk record and DISK storage mode are still authoritative.\n'
           '        ; Free the existing backing run before publishing any RAM owner or\n'
           '        ; subtracting from proc_swap_blocks_used. On refusal the ordinary\n'
           '        ; post-unpin MM rollback leaves the disk record intact for retry.\n'
           '        move    1,15\n'
           '        move    2,16\n'
           '        pushj   17,backstore_free\n')
    new = old.replace('        move    1,15\n',
                      '        pushj   17,daimos_v1494_arm\n'
                      '        move    1,15\n', 1)
    swap = replace_one(swap, old, new)

    # The service still uses the authentic event helper. This read-only
    # witness executes after it; it never changes the fatal decision.
    old = ('proc_swap_service_failed:\n'
           '        move    1,(17)\n'
           '        movem   1,proc_sched_cursor\n'
           '        movei   2,SYS_EVENT_TERM\n'
           '        pushj   17,proc_event_apply\n'
           '        sub     17,kconst_1_1\n')
    new = old.replace('        sub     17,kconst_1_1\n',
                      '        pushj   17,daimos_v1494_term_witness\n'
                      '        sub     17,kconst_1_1\n', 1)
    swap = replace_one(swap, old, new)

    swap += '''
; v1494 DISPOSABLE GUEST ONLY: corrupt one genuine owned bitmap bit.
; Triggered only after successful physical swap payload read and MM unpin.
daimos_v1494_arm:
        skipn   daimos_v1494_armed
        jrst    daimos_v1494_arm_new
        popj    17,
daimos_v1494_arm_new:
        ; INIT and early boot/provider witnesses must remain untouched.
        ; F07 later creates ordinary slots >= 010 (octal), whose loss
        ; can be reaped without stopping the entire workload driver.
        cail    10,010
        jrst    daimos_v1494_arm_selected
        popj    17,
daimos_v1494_arm_selected:
        movem   10,daimos_v1494_slot
        movem   15,daimos_v1494_first
        movem   16,daimos_v1494_blocks
        move    4,15
        idivi   4,044
        add     4,backstore_bitmap
        movei   6,1
        lsh     6,0(5)
        tdne    6,(4)
        jrst    daimos_v1494_bit_owned
        aos     daimos_v1494_errors
        popj    17,
daimos_v1494_bit_owned:
        movem   4,daimos_v1494_bitmap_addr
        move    7,(4)
        movem   7,daimos_v1494_bitmap_saved
        andcm   7,6
        movem   7,(4)
        movei   4,1
        movem   4,daimos_v1494_armed
        aos     daimos_v1494_faults
        popj    17,

; The service receives a negative swap-in result and invokes real TERM.
; It must have attempted PREVM teardown without publishing a RAM owner.
daimos_v1494_term_witness:
        push    17,4
        push    17,5
        push    17,6
        move    4,-3(17)               ; service's pending slot
        came    4,daimos_v1494_slot
        jrst    daimos_v1494_term_done
        aos     daimos_v1494_terms
        move    5,4
        lsh     5,1
        add     5,4
        add     5,proc_table
        move    6,(5)
        trne    6,PROC_TRANSITION_RH
        jrst    daimos_v1494_term_transition
        aos     daimos_v1494_errors
daimos_v1494_term_transition:
        hlrz    6,6
        move    6,067(6)
        tlne    6,0100000              ; PREVM after refused detach
        jrst    daimos_v1494_term_marked
        aos     daimos_v1494_errors
daimos_v1494_term_marked:
        move    5,proc_swap_records
        add     5,4
        move    6,(5)
        hlrz    5,6
        came    5,daimos_v1494_first
        aos     daimos_v1494_errors
        hrrz    5,6
        came    5,daimos_v1494_blocks
        aos     daimos_v1494_errors
daimos_v1494_term_done:
        pop     17,6
        pop     17,5
        pop     17,4
        popj    17,
'''

    # Exact allocation identity, not all frees: unrelated process and
    # MEMFS allocations must go through the original allocator unchanged.
    old = ('backstore_free:\n'
           '        push    17,1\n'
           '        push    17,2\n')
    new = '''backstore_free:
        skipn   daimos_v1494_armed
        jrst    daimos_v1494_free_original
        push    17,4
        push    17,5
        move    4,daimos_v1494_armed
        caie    4,1
        jrst    daimos_v1494_free_other
        move    4,daimos_v1494_first
        came    1,4
        jrst    daimos_v1494_free_other
        move    4,daimos_v1494_blocks
        came    2,4
        jrst    daimos_v1494_free_other
        aos     daimos_v1494_free_calls
        move    4,daimos_v1494_free_calls
        caie    4,3
        jrst    daimos_v1494_free_other
        ; The real fatal event's FIRST detach must have failed and
        ; registered PREVM before an idle finalizer can retry.
        move    4,daimos_v1494_slot
        move    5,4
        lsh     5,1
        add     5,4
        add     5,proc_table
        move    4,(5)
        trne    4,0200000
        jrst    daimos_v1494_retry_locked
        aos     daimos_v1494_errors
daimos_v1494_retry_locked:
        hlrz    5,4
        move    4,067(5)
        tlne    4,0100000
        jrst    daimos_v1494_retry_marked
        aos     daimos_v1494_errors
daimos_v1494_retry_marked:
        move    5,daimos_v1494_bitmap_addr
        move    4,daimos_v1494_bitmap_saved
        movem   4,(5)                   ; repair only injected bit
        aos     daimos_v1494_repairs
        movei   4,2
        movem   4,daimos_v1494_armed   ; no later run is intercepted
daimos_v1494_free_other:
        pop     17,5
        pop     17,4
daimos_v1494_free_original:
        push    17,1
        push    17,2
'''
    back = replace_one(back, old, new)

    # The MRES build deliberately strips backstore.s at the first .bss,
    # using the fixed KCORE backstore_entry_v484.s as the shared ABI.
    # Store all diagnostic words there, not in the movable source.
    entry += '\n; v1494 DISPOSABLE GUEST ONLY: fault evidence.\n        .bss\n'
    for label in ('armed', 'faults', 'free_calls', 'terms', 'repairs', 'errors',
                  'slot', 'first', 'blocks', 'bitmap_addr', 'bitmap_saved'):
        symbol = 'daimos_v1494_' + label
        entry += '        .globl %s\n%s: .block 1\n' % (symbol, symbol)

    swap_path.write_text(swap)
    back_path.write_text(back)
    entry_path.write_text(entry)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-swap-refusal-fullguest-v1494.py KERNEL')
    inject(Path(sys.argv[1]))
