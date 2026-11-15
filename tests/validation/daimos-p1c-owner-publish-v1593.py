#!/usr/bin/env python3
"""Observe the exact successful process publication of each v1592 owner.

Append only disposable witnesses AFTER the original proc_storage_publish_v30
success and TRANSITION unlock; do not initiate swap, alter policy or I/O.
"""

from pathlib import Path
import sys


def replace_one(text, old, new, label):
    assert text.count(old) == 1, 'v1593 moved source anchor: ' + label
    return text.replace(old, new, 1)


def instrument(root):
    path = root / 'proc/proc_swap_pdp6.s'
    original = path.read_text()
    anchor = ('''        move    1,(11)
        andcmi  1,PROC_TRANSITION_RH
        movem   1,(11)
        ; A successful restore retires the owner's retry deadline even
''')
    replacement = ('''        move    1,(11)
        andcmi  1,PROC_TRANSITION_RH
        movem   1,(11)
        ; The original storage publication succeeded before this observer.
        ; AC10 is its actual process slot, not the last global cursor.
        move    5,10
        came    5,daimos_v1592_first_slot
        jrst    daimos_v1593_check_second
        aos     daimos_v1593_first_published
        jrst    daimos_v1593_pub_done
daimos_v1593_check_second:
        came    5,daimos_v1592_second_slot
        jrst    daimos_v1593_pub_done
        aos     daimos_v1593_second_published
        movem   5,daimos_v1593_second_slot
        move    5,(11)
        movem   5,daimos_v1593_second_procword
        hrrz    5,1(11)
        movem   5,daimos_v1593_second_vm
        move    5,(12)
        movem   5,daimos_v1593_second_record
        hlrz    5,(11)
        move    5,PROC_SWAP_BACKING_OFFSET(5)
        movem   5,daimos_v1593_second_uarea_backing
daimos_v1593_pub_done:
        ; A successful restore retires the owner's retry deadline even
''')
    updated = replace_one(original, anchor, replacement,
                          'actual DISK->RESIDENT transition commit')
    globals_ = ''.join('        .globl daimos_v1593_%s\n' % key for key in
                       ('first_published', 'second_published', 'second_slot',
                        'second_procword', 'second_vm', 'second_record',
                        'second_uarea_backing'))
    path.write_text(globals_ + updated)

    path = root / 'storage/backstore_entry_v484.s'
    content = path.read_text()
    anchor = 'daimos_v1592_second_woke: .block 1\n'
    extra = ''.join('        .globl daimos_v1593_%s\n'
                    'daimos_v1593_%s: .block 1\n' % (key, key)
                    for key in
                    ('first_published', 'second_published', 'second_slot',
                     'second_procword', 'second_vm', 'second_record',
                     'second_uarea_backing'))
    path.write_text(replace_one(content, anchor, anchor + extra,
                                'physical original-backed witness extent'))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1593 KERNEL_COPY')
    instrument(Path(sys.argv[1]))
    print('v1593: original post-success per-slot process publication observed')
