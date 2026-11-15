#!/usr/bin/env python3
"""Disposable physical timer frontier experiment during MEMFS snapshot.

One *existing* timed, sleeping, disk-backed process gets a one-tick
deadline at snapshot entry. Only the genuine PI6 timer and scheduler
may wake it and execute the slot-0 swap service. No injected swap-in
call, device completion, scheduler kick or fake return is permitted.
"""

from pathlib import Path
import sys


def once(text, anchor, replacement, label):
    count = text.count(anchor)
    assert count == 1, '%s: expected one anchor, got %d' % (label, count)
    return text.replace(anchor, replacement, 1)


def instrument(root):
    snap = root / 'fs/memfs_snapshot_pdp6.s'
    text = snap.read_text()
    anchor = '        setom   daimos_v1584_snapshot_live\n'
    text = once(text, anchor,
        anchor +
        '        move    2,proc_timer_clock\n'
        '        movem   2,daimos_v1585_start_tick\n'
        '        pushj   17,daimos_v1585_timer_arm\n', 'snapshot arm call')
    anchor = ('memfs_snapshot_shutdown_return:\n'
              '        setzm   daimos_v1584_snapshot_live\n')
    text = once(text, anchor,
        anchor +
        '        move    2,proc_timer_clock\n'
        '        movem   2,daimos_v1585_end_tick\n', 'snapshot exit')
    anchor = '        .bss\n; Zero means volatile/disabled; otherwise first-block,,reserved-block-count.\n'
    timer = '''; Diagnostic v1585: retime one genuine sleeping disk process at
; snapshot entry. No RUN state, run-queue entry or PI request is altered.
; The unmodified 60 Hz PI6 scheduler performs every subsequent step.
; Process descriptors are three words, with timer-tagged deadline in
; sched RH; proc_timer_next is the original nearest-deadline frontier.
daimos_v1585_timer_arm:
        movei   1,1
        move    2,proc_table
        addi    2,3
daimos_v1585_timer_scan:
        caml    1,proc_high_slot
        jrst    daimos_v1585_timer_done
        hlrz    3,2(2)
        andi    3,0700000
        caie    3,0300000             ; original SLEEP state
        jrst    daimos_v1585_timer_next
        hrrz    3,2(2)
        trnn    3,0400000             ; actual timed SLEEP
        jrst    daimos_v1585_timer_next
        hrrz    3,1(2)
        jumpn   3,daimos_v1585_timer_next ; VM must be on DISK
        move    3,proc_swap_records
        add     3,1
        skipn   (3)                   ; original swap backing record
        jrst    daimos_v1585_timer_next
        move    3,(2)
        trne    3,0200000             ; no owner in TRANSITION
        jrst    daimos_v1585_timer_next
        ; One original timer deadline, next real PI6 clock tick.
        move    4,proc_timer_clock
        addi    4,1
        andi    4,0377777
        move    5,4
        ori     5,0400000
        hrrm    5,2(2)
        movem   1,daimos_v1585_slot
        aos     daimos_v1585_armed
        ; Preserve an earlier timer or already-DUE frontier.
        skipn   6,proc_timer_next
        jrst    daimos_v1585_timer_frontier
        tlne    6,0200000
        jrst    daimos_v1585_timer_done
        hrrz    6,6
        sub     6,proc_timer_clock
        andi    6,0377777
        caile   6,1
        jrst    daimos_v1585_timer_frontier
        jrst    daimos_v1585_timer_done
daimos_v1585_timer_frontier:
        hrli    4,0400000
        movem   4,proc_timer_next
        jrst    daimos_v1585_timer_done
daimos_v1585_timer_next:
        addi    2,3
        aoja    1,daimos_v1585_timer_scan
daimos_v1585_timer_done:
        popj    17,

'''
    text = once(text, anchor, timer + anchor, 'timer test helper')
    text = ('''        .globl proc_timer_clock
        .globl proc_timer_next
        .globl proc_table
        .globl proc_high_slot
        .globl proc_swap_records
        .globl daimos_v1585_start_tick
        .globl daimos_v1585_end_tick
        .globl daimos_v1585_slot
        .globl daimos_v1585_armed
''' + text)
    snap.write_text(text)

    sched = root / 'proc/proc_pdp6.s'
    text = sched.read_text()
    anchor = ('''        movem   3,2(2)
        tlne    3,0400000              ; STOP remains off the run queue
        jrst    proc_timer_service_next
''')
    replacement = ('''        movem   3,2(2)
        ; Original PI6 timer actually woke the selected swapped slot.
        came    1,daimos_v1585_slot
        jrst    daimos_v1585_timer_wake_done
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1585_timer_wake_done
        aos     daimos_v1585_woke
daimos_v1585_timer_wake_done:
        tlne    3,0400000              ; STOP remains off the run queue
        jrst    proc_timer_service_next
''')
    text = once(text, anchor, replacement, 'original timer service')
    text = ('        .globl daimos_v1584_snapshot_live\n'
            '        .globl daimos_v1585_slot\n'
            '        .globl daimos_v1585_woke\n' + text)
    sched.write_text(text)

    backing = root / 'storage/backstore_entry_v484.s'
    text = backing.read_text()
    anchor = 'daimos_v1584_last_slot: .block 1\n'
    extra = ''
    for name in ('slot', 'armed', 'woke', 'start_tick', 'end_tick'):
        sym = 'daimos_v1585_' + name
        extra += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    text = once(text, anchor, anchor + extra, 'test-only counters')
    backing.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-snapshot-timer-v1585.py KERNEL_COPY')
    instrument(Path(sys.argv[1]))
    print('v1585: armed one true PI6 timer during actual snapshot')
