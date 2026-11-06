#!/usr/bin/env python3
"""Record the exact missing-owner branch before the PDP-6 fatal HALT.

Only a disposable guest is modified. Both original failure branches
still terminate in proc_fatal_close_no_owner_v879; the normal owner
path and permanent kernel contain none of these counters.
"""

from pathlib import Path
import sys


def inject(kernel):
    path = kernel / 'proc/proc_pdp6.s'
    source = path.read_text()
    begin = source.index('proc_fatal_close_current_v879:\n')
    end = source.index('\nproc_fatal_close_retry_v879:', begin)
    segment = source[begin:end]
    branches = ('        skipn   proc_current_slot\n'
                '        jrst    proc_fatal_close_no_owner_v879\n'
                '        skipn   file_table\n'
                '        jrst    proc_fatal_close_no_owner_v879\n')
    if segment.count(branches) != 1:
        raise ValueError('v1217: fatal owner branch moved')
    replacement = ('        skipn   proc_current_slot\n'
                   '        jrst    daimos_f07o_missing_slot_v1217\n'
                   '        skipn   file_table\n'
                   '        jrst    daimos_f07o_missing_file_v1217\n')
    source = source[:begin] + segment.replace(branches, replacement, 1) + source[end:]

    anchor = ('proc_fatal_close_no_owner_v879:\n'
              '        halt    3\n')
    if source.count(anchor) != 1:
        raise ValueError('v1217: fatal no-owner HALT moved')
    capture = '''proc_fatal_close_no_owner_v879:
        ; Disposable-only snapshot of the already-failing owner path.
        move    7,proc_current_slot
        movem   7,daimos_f07o_slot_v1217
        move    7,file_table
        movem   7,daimos_f07o_files_v1217
        move    7,proc_current_ptr
        movem   7,daimos_f07o_ptr_v1217
        jumpe   7,daimos_f07o_no_desc_v1217
        move    6,(7)
        movem   6,daimos_f07o_meta_v1217
        move    6,1(7)
        movem   6,daimos_f07o_vm_v1217
        move    6,2(7)
        movem   6,daimos_f07o_sched_v1217
daimos_f07o_no_desc_v1217:
        halt    3
'''
    source = source.replace(anchor, capture, 1)
    anchor = ('daimos_f07o_no_desc_v1217:\n'
              '        halt    3\n'
              '        jrst    .-1\n')
    if source.count(anchor) != 1:
        raise ValueError('v1217: original fatal HALT retry moved')
    source = source.replace(anchor, anchor + '''daimos_f07o_missing_slot_v1217:
        aos     daimos_f07o_no_slot_v1217
        jrst    proc_fatal_close_no_owner_v879
daimos_f07o_missing_file_v1217:
        aos     daimos_f07o_no_file_v1217
        jrst    proc_fatal_close_no_owner_v879
''', 1)
    source += '\n        .bss\n'
    for name in ('slot', 'files', 'ptr', 'meta', 'vm', 'sched',
                 'no_slot', 'no_file'):
        symbol = 'daimos_f07o_%s_v1217' % name
        source += '        .globl %s\n%s: .block 1\n' % (symbol, symbol)
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: owner-branch-v1217.py DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
