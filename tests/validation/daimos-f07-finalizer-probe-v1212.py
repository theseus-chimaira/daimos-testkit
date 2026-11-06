#!/usr/bin/env python3
"""Test-only exit/finalizer lifecycle probe for the F07 pressure guest.

The probe is injected only into the disposable guest's proc_pdp6.s.
It records the last owner EXIT transition and the finalizer's failing
owner without altering the process, MM, swap, or FILE descriptors.
All instrumentation and BSS vanish from the production build.
"""

from pathlib import Path
import sys


def inject(kernel):
    path = kernel / 'proc/proc_pdp6.s'
    source = path.read_text()
    anchor = 'proc_exit_current:\n'
    assert source.count(anchor) == 1, 'v1212: owner EXIT moved'
    source = source.replace(anchor, '''proc_exit_current:
        ; v1212: capture the owner BEFORE proc_exit_finish resets slot 0.
        aos     daimos_f07f_exit_calls_v1212
        move    7,proc_current_slot
        movem   7,daimos_f07f_exit_slot_v1212
        move    7,proc_current_ptr
        movem   7,daimos_f07f_exit_ptr_v1212
        jumpe   7,daimos_f07f_no_ptr_v1212
        move    7,(7)
        movem   7,daimos_f07f_exit_meta_v1212
daimos_f07f_no_ptr_v1212:
''', 1)
    # The written marker uses exactly the original AC6 and owner u-area.
    prefix, suffix = source.split('proc_exit_current:', 1)
    body, tail = suffix.split('\nproc_exit_release_failed:', 1)
    mark = '        movem   6,PROC_FINALIZE_OFFSET(5)\n'
    assert body.count(mark) == 1, 'v1212: original marker moved'
    body = body.replace(mark, mark + '''        movem   5,daimos_f07f_written_uarea_v1212
        movem   6,daimos_f07f_written_marker_v1212
''', 1)
    source = prefix + 'proc_exit_current:' + body + '\nproc_exit_release_failed:' + tail

    counter_labels = (
        ('finish_owner', 'proc_finish_slot_owner_v932:'),
        ('prevm_fail', 'proc_finish_prevm_fail_v1081:'),
        ('vm_done', 'proc_finish_vm_done:'),
        ('uarea_defer', 'proc_finish_defer_uarea_v881:'),
        ('hup_fail', 'proc_finish_hup_fail_v876:'),
        ('finish_fail', 'proc_finish_fail:'),
        ('exit_fail', 'proc_exit_release_failed:'),
        ('fatal_no_owner', 'proc_fatal_close_no_owner_v879:'),
    )
    for name, label in counter_labels:
        assert source.count(label) == 1, 'v1212: label moved: ' + label
        source = source.replace(label, label + '\n' +
            '        aos     daimos_f07f_%s_v1212' % name, 1)

    # AC10/11/12 are live in the finalizer, but only AC7 is used for
    # diagnostic memory reads. The original AC1 return and saved AC10..16
    # remain untouched. A failed owner is not released or resumed.
    anchor = ('proc_finish_fail:\n'
              '        aos     daimos_f07f_finish_fail_v1212\n')
    assert source.count(anchor) == 1
    source = source.replace(anchor, anchor + '''        movem   10,daimos_f07f_bad_slot_v1212
        movem   11,daimos_f07f_bad_status_v1212
        movem   12,daimos_f07f_bad_descriptor_v1212
        move    7,(12)
        movem   7,daimos_f07f_bad_meta_v1212
        trnn    7,0400000
        jrst    daimos_f07f_no_uarea_v1212
        hlrz    7,7
        jumpe   7,daimos_f07f_no_uarea_v1212
        move    7,067(7)
        movem   7,daimos_f07f_bad_marker_v1212
daimos_f07f_no_uarea_v1212:
''', 1)
    fatal = ('proc_fatal_close_no_owner_v879:\n'
             '        aos     daimos_f07f_fatal_no_owner_v1212\n')
    assert source.count(fatal) == 1
    source = source.replace(fatal, fatal + '''        move    7,proc_current_slot
        movem   7,daimos_f07f_fatal_slot_v1212
        move    7,proc_current_ptr
        movem   7,daimos_f07f_fatal_ptr_v1212
        move    7,file_table
        movem   7,daimos_f07f_fatal_files_v1212
''', 1)
    diagnostics = [
        'exit_calls', 'exit_slot', 'exit_ptr', 'exit_meta',
        'written_uarea', 'written_marker',
        'finish_owner', 'prevm_fail', 'vm_done', 'uarea_defer',
        'hup_fail', 'finish_fail', 'exit_fail', 'fatal_no_owner',
        'bad_slot', 'bad_status', 'bad_descriptor', 'bad_meta',
        'bad_marker',
        'fatal_slot', 'fatal_ptr', 'fatal_files',
    ]
    source += '\n        .bss\n'
    for name in diagnostics:
        symbol = 'daimos_f07f_%s_v1212' % name
        source += '        .globl %s\n%s: .block 1\n' % (symbol, symbol)
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1212.py DISPOSABLE_KERNEL_ROOT')
    inject(Path(sys.argv[1]))
