#!/usr/bin/env python3
"""Instrument the actual owner-side TERM return of the v1499 physical guest.

All changes live in the disposable F07 source copy, never in KCORE.
Record the target at fault injection and observe fatal-event creation,
owner-side consumption and completion without modifying any decisions.
"""

from pathlib import Path
import runpy
import sys


HERE = Path(__file__).resolve().parent
NAMES = ('armed_fdctl', 'armed_sched', 'armed_pc',
         'owner_term_count', 'owner_slot', 'owner_fdctl_before',
         'owner_backing_before', 'owner_commit_count',
         'owner_fdctl_after', 'private_fatal_count', 'private_status',
         'finish_count', 'finish_status', 'zombie_count')
ARRAYS = ('def_count', 'def_kind', 'def_prior')


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise AssertionError('v1504 production anchor drift: %r' % old)
    return source.replace(old, new, 1)


def instrument(kernel):
    base = HERE / 'daimos-backstore-term-branch-v1499.py'
    runpy.run_path(str(base))['instrument'](kernel)
    swap_path = kernel / 'proc/proc_swap_pdp6.s'
    proc_path = kernel / 'proc/proc_pdp6.s'
    mach_path = kernel / 'proc/mach_user_pdp6.s'
    data_path = kernel / 'storage/backstore_entry_v484.s'
    swap = swap_path.read_text()
    proc = proc_path.read_text()
    mach = mach_path.read_text()
    data = data_path.read_text()

    swap = replace_once(swap,
        'daimos_v1494_arm_selected:\n'
        '        movem   10,daimos_v1494_slot\n',
        'daimos_v1494_arm_selected:\n'
        '        movem   10,daimos_v1494_slot\n'
        '        move    4,10\n'
        '        lsh     4,1\n'
        '        add     4,10\n'
        '        add     4,proc_table\n'
        '        move    6,2(4)\n'
        '        movem   6,daimos_v1504_armed_sched\n'
        '        hlrz    5,(4)\n'
        '        move    6,024(5)\n'
        '        movem   6,daimos_v1504_armed_fdctl\n'
        '        move    6,020(5)\n'
        '        movem   6,daimos_v1504_armed_pc\n')

    # Capture deferred-event attempts for all slots because the fault
    # victim is selected only after one physical swap read. AC10 is the
    # actual validated process slot at this instruction boundary.
    proc = replace_once(proc,
        'evt_def_record_v970:\n'
        '        iorm    2,PROC_FDCTL_OFFSET(1)\n',
        'evt_def_record_v970:\n'
        '        push    17,4\n'
        '        move    4,010\n'
        '        caige   4,0100\n'
        '        jrst    daimos_v1504_def_valid\n'
        '        jrst    daimos_v1504_def_done\n'
        'daimos_v1504_def_valid:\n'
        '        aos     daimos_v1504_def_count(4)\n'
        '        movem   011,daimos_v1504_def_kind(4)\n'
        '        move    4,PROC_FDCTL_OFFSET(1)\n'
        '        movem   4,daimos_v1504_def_prior(010)\n'
        'daimos_v1504_def_done:\n'
        '        pop     17,4\n'
        '        iorm    2,PROC_FDCTL_OFFSET(1)\n')

    proc = replace_once(proc,
        'proc_fatal_close_current_v879:\n',
        'proc_fatal_close_current_v879:\n'
        '        push    17,4\n'
        '        skipn   daimos_v1494_armed\n'
        '        jrst    daimos_v1504_fatal_other\n'
        '        move    4,proc_current_slot\n'
        '        came    4,daimos_v1494_slot\n'
        '        jrst    daimos_v1504_fatal_other\n'
        '        aos     daimos_v1504_private_fatal_count\n'
        '        movem   1,daimos_v1504_private_status\n'
        'daimos_v1504_fatal_other:\n'
        '        pop     17,4\n')

    proc = replace_once(proc,
        'proc_finish_common_v932:\n',
        'proc_finish_common_v932:\n'
        '        push    17,4\n'
        '        skipn   daimos_v1494_armed\n'
        '        jrst    daimos_v1504_finish_other\n'
        '        move    4,1\n'
        '        came    4,daimos_v1494_slot\n'
        '        jrst    daimos_v1504_finish_other\n'
        '        aos     daimos_v1504_finish_count\n'
        '        movem   2,daimos_v1504_finish_status\n'
        'daimos_v1504_finish_other:\n'
        '        pop     17,4\n')

    proc = replace_once(proc,
        'proc_finish_zombie:\n',
        'proc_finish_zombie:\n'
        '        push    17,4\n'
        '        skipn   daimos_v1494_armed\n'
        '        jrst    daimos_v1504_zombie_other\n'
        '        move    4,10\n'
        '        came    4,daimos_v1494_slot\n'
        '        jrst    daimos_v1504_zombie_other\n'
        '        aos     daimos_v1504_zombie_count\n'
        'daimos_v1504_zombie_other:\n'
        '        pop     17,4\n')

    mach = replace_once(mach,
        'proc_deferred_term_v970:\n'
        '        movei 1,0400001\n',
        'proc_deferred_term_v970:\n'
        '        push    17,4\n'
        '        skipn   daimos_v1494_armed\n'
        '        jrst    daimos_v1504_term_other\n'
        '        move    4,proc_current_slot\n'
        '        came    4,daimos_v1494_slot\n'
        '        jrst    daimos_v1504_term_other\n'
        '        aos     daimos_v1504_owner_term_count\n'
        '        movem   4,daimos_v1504_owner_slot\n'
        '        movem   3,daimos_v1504_owner_fdctl_before\n'
        '        move    4,proc_swap_records\n'
        '        add     4,proc_current_slot\n'
        '        move    4,(4)\n'
        '        movem   4,daimos_v1504_owner_backing_before\n'
        'daimos_v1504_term_other:\n'
        '        pop     17,4\n'
        '        movei 1,0400001\n')

    mach = replace_once(mach,
        '        andcam 3,-2(2)\n'
        '        pop 17,3\n',
        '        andcam 3,-2(2)\n'
        '        push    17,4\n'
        '        skipn   daimos_v1494_armed\n'
        '        jrst    daimos_v1504_commit_other\n'
        '        move    4,proc_current_slot\n'
        '        came    4,daimos_v1494_slot\n'
        '        jrst    daimos_v1504_commit_other\n'
        '        aos     daimos_v1504_owner_commit_count\n'
        '        move    4,-2(2)\n'
        '        movem   4,daimos_v1504_owner_fdctl_after\n'
        'daimos_v1504_commit_other:\n'
        '        pop     17,4\n'
        '        pop 17,3\n')

    data += '\n; v1504 DISPOSABLE owner-return/creation witnesses.\n'
    data += '        .bss\n'
    for name in NAMES:
        sym = 'daimos_v1504_' + name
        data += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    for name in ARRAYS:
        sym = 'daimos_v1504_' + name
        data += '        .globl %s\n%s: .block 0100\n' % (sym, sym)

    swap_path.write_text(swap)
    proc_path.write_text(proc)
    mach_path.write_text(mach)
    data_path.write_text(data)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1504.py DISPOSABLE_KERNEL')
    instrument(Path(sys.argv[1]))
