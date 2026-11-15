#!/usr/bin/env python3
"""Retime TWO distinct real sleeping DISK owners at one PI6 frontier.

Apply after original v1584/v1585/v1588 disposable source instruments.
Neither scheduler state, swap service nor hardware completion is faked.
"""

from pathlib import Path
import sys


def once(text, old, new, name):
    assert text.count(old) == 1, 'v1592 anchor drift: ' + name
    return text.replace(old, new, 1)


def instrument(root):
    path = root / 'fs/memfs_snapshot_pdp6.s'
    text = path.read_text()
    text = once(text,
                'daimos_v1585_timer_scan:\n'
                '        caml    1,proc_high_slot\n'
                '        jrst    daimos_v1585_timer_done\n',
                'daimos_v1585_timer_scan:\n'
                '        caml    1,proc_high_slot\n'
                '        jrst    daimos_v1592_timer_end\n',
                'bound check ends at actual high slot')
    text = once(text,
                '        movem   1,daimos_v1585_slot\n'
                '        aos     daimos_v1585_armed\n',
                '        movem   1,daimos_v1585_slot\n'
                '        skipn   daimos_v1585_armed\n'
                '        jrst    daimos_v1592_mark_first\n'
                '        movem   1,daimos_v1592_second_slot\n'
                '        jrst    daimos_v1592_marked\n'
                'daimos_v1592_mark_first:\n'
                '        movem   1,daimos_v1592_first_slot\n'
                'daimos_v1592_marked:\n'
                '        aos     daimos_v1585_armed\n',
                'preserve distinct selected original slots')
    text = once(text,
                'daimos_v1585_timer_done:\n'
                '        popj    17,\n',
                'daimos_v1585_timer_done:\n'
                '        move    3,daimos_v1585_armed\n'
                '        caie    3,1\n'
                '        jrst    daimos_v1592_timer_end\n'
                '        ; Continue the original bounded descriptor scan once.\n'
                '        addi    2,3\n'
                '        aoja    1,daimos_v1585_timer_scan\n'
                'daimos_v1592_timer_end:\n'
                '        popj    17,\n',
                'scan next sleeping owner without changing its state')
    text = ('        .globl daimos_v1592_first_slot\n'
            '        .globl daimos_v1592_second_slot\n' + text)
    path.write_text(text)

    path = root / 'proc/proc_pdp6.s'
    text = path.read_text()
    text = once(text,
                '        came    1,daimos_v1585_slot\n'
                '        jrst    daimos_v1585_timer_wake_done\n'
                '        skipn   daimos_v1584_snapshot_live\n'
                '        jrst    daimos_v1585_timer_wake_done\n'
                '        aos     daimos_v1585_woke\n'
                'daimos_v1585_timer_wake_done:\n',
                '        skipn   daimos_v1584_snapshot_live\n'
                '        jrst    daimos_v1585_timer_wake_done\n'
                '        came    1,daimos_v1592_first_slot\n'
                '        jrst    daimos_v1592_wake_second\n'
                '        aos     daimos_v1592_first_woke\n'
                '        jrst    daimos_v1585_timer_wake_done\n'
                'daimos_v1592_wake_second:\n'
                '        came    1,daimos_v1592_second_slot\n'
                '        jrst    daimos_v1585_timer_wake_done\n'
                '        aos     daimos_v1592_second_woke\n'
                '        aos     daimos_v1585_woke\n'
                'daimos_v1585_timer_wake_done:\n',
                'count two genuine original PI6 timer-service wakeups')
    text = ('        .globl daimos_v1592_first_slot\n'
            '        .globl daimos_v1592_second_slot\n'
            '        .globl daimos_v1592_first_woke\n'
            '        .globl daimos_v1592_second_woke\n' + text)
    path.write_text(text)

    path = root / 'storage/backstore_entry_v484.s'
    text = path.read_text()
    old = 'daimos_v1585_end_tick: .block 1\n'
    extra = ''
    for key in ('first_slot', 'second_slot', 'first_woke', 'second_woke'):
        name = 'daimos_v1592_' + key
        extra += '        .globl %s\n%s: .block 1\n' % (name, name)
    path.write_text(once(text, old, old + extra, 'test-only owner counters'))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1592 KERNEL_COPY')
    instrument(Path(sys.argv[1]))
    print('v1592: two distinct actual timer-tagged DISK owners')
