#!/usr/bin/env python3
"""Disposable physical PDP-6 snapshot/independent-swap overlap observers.

The probes record source-authentic scheduler and Type-236 PI2 activity.
They do not initiate or complete swaps, manufacture any I/O status or
modify production DAIMOS. Tests must still prove real physical progress.
"""

from pathlib import Path
import sys


def replace_one(text, needle, replacement, name):
    assert text.count(needle) == 1, (name, text.count(needle))
    return text.replace(needle, replacement, 1)


def instrument(root):
    snapshot = root / 'fs/memfs_snapshot_pdp6.s'
    source = snapshot.read_text()
    anchor = ('memfs_snapshot_shutdown:\n'
              '        add     17,[7,,7]\n'
              '        movei   0,-6(17)\n'
              '        hrli    0,010\n'
              '        blt     0,(17)\n')
    source = replace_one(source, anchor,
                         anchor +
                         '        skipn   proc_swap_blocks_used\n'
                         '        jrst    memfs_snapshot_shutdown_fail\n'
                         '        setom   daimos_v1584_snapshot_live\n',
                         'snapshot entry')
    anchor = 'memfs_snapshot_shutdown_return:\n'
    source = replace_one(source, anchor,
                         anchor + '        setzm   daimos_v1584_snapshot_live\n',
                         'snapshot return')
    source = ('        .globl  daimos_v1584_snapshot_live\n'
              '        .globl  proc_swap_blocks_used\n' + source)
    snapshot.write_text(source)

    swap = root / 'proc/proc_swap_pdp6.s'
    source = swap.read_text()
    anchor = ('proc_swap_in:\n'
              '        add     17,kconst_7_7\n'
              '        movei   0,-6(17)\n'
              '        hrli    0,10\n'
              '        blt     0,(17)\n')
    replacement = ('''proc_swap_in:
        add     17,kconst_7_7
        movei   0,-6(17)
        hrli    0,10
        blt     0,(17)
        ; A real scheduler-initiated swap-in started during snapshot.
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1584_swap_entry_normal
        move    5,proc_sched_cursor
        trnn    5,0400             ; independently scheduled slot-0 service
        jrst    daimos_v1584_swap_entry_normal
        aos     daimos_v1584_swap_started
        movem   1,daimos_v1584_last_slot
daimos_v1584_swap_entry_normal:
''')
    source = replace_one(source, anchor, replacement, 'swap-in entry')
    anchor = ('proc_swap_in_read_offset:\n'
              '        move    1,15\n'
              '        move    2,16\n'
              '        add     3,(17)\n'
              '        pushj   17,backstore_read\n'
              '        jumpn   1,proc_swap_in_read_fail\n')
    replacement = ('''proc_swap_in_read_offset:
        move    1,15
        move    2,16
        add     3,(17)
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1584_swap_read_normal
        aos     daimos_v1584_swap_reads
        setom   daimos_v1584_swap_read_active
daimos_v1584_swap_read_normal:
        pushj   17,backstore_read
        setzm   daimos_v1584_swap_read_active
        jumpn   1,proc_swap_in_read_fail
''')
    source = replace_one(source, anchor, replacement, 'actual swap READ')
    anchor = ('        andcam  2,PROC_FINALIZE_OFFSET(1)\n'
              '        sub     17,kconst_1_1\n'
              '        setz    1,\n'
              '        jrst    proc_swap_in_restore\n')
    replacement = ('''        andcam  2,PROC_FINALIZE_OFFSET(1)
        ; Count only actual completed DISK->RESIDENT publication.
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1584_swap_publish_done
        aos     daimos_v1584_swap_completed
daimos_v1584_swap_publish_done:
        sub     17,kconst_1_1
        setz    1,
        jrst    proc_swap_in_restore
''')
    source = replace_one(source, anchor, replacement, 'published restore')
    source = ('''        .globl daimos_v1584_snapshot_live
        .globl daimos_v1584_swap_started
        .globl daimos_v1584_swap_completed
        .globl daimos_v1584_swap_reads
        .globl daimos_v1584_swap_read_active
        .globl daimos_v1584_last_slot
''' + source)
    swap.write_text(source)

    driver = root / 'drivers/drm236_io.s'
    source = driver.read_text()
    anchor = ('        add     017,kconst_3_3\n'
              '        pushj   017,storage_request_init\n'
              '\n'
              'drm236_runtime_retry:\n')
    replacement = ('''        add     017,kconst_3_3
        pushj   017,storage_request_init
        ; Mark only the real slot-0 swap service's READ descriptor.
        skipn   daimos_v1584_swap_read_active
        jrst    drm236_runtime_retry
        move    5,proc_sched_cursor
        trnn    5,0400
        jrst    drm236_runtime_retry
        move    5,-1(017)
        caie    5,0230
        jrst    drm236_runtime_retry
        movei   5,-2(017)
        movem   5,daimos_v1584_swap_target

drm236_runtime_retry:
''')
    source = replace_one(source, anchor, replacement, 'READ descriptor')
    anchor = ('        trnn    1,DRM_DR_DONE\n'
              '        jrst    pdp10_pi_dispatch_done\n'
              '        cono    0400,DRM_DR_DESELECT\n')
    replacement = ('''        trnn    1,DRM_DR_DONE
        jrst    pdp10_pi_dispatch_done
        ; Actual hardware-simulator DR_DONE PI2, not a test callback.
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1584_dr_done_normal
        aos     daimos_v1584_snapshot_pi2
        hrrz    2,drm236_active_request
        jumpe   2,daimos_v1584_dr_done_normal
        came    2,daimos_v1584_swap_target
        jrst    daimos_v1584_dr_done_normal
        aos     daimos_v1584_swap_pi2
        setzm   daimos_v1584_swap_target
daimos_v1584_dr_done_normal:
        cono    0400,DRM_DR_DESELECT
''')
    source = replace_one(source, anchor, replacement, 'actual PI2 DONE')
    source = ('''        .globl daimos_v1584_snapshot_live
        .globl daimos_v1584_snapshot_pi2
        .globl daimos_v1584_swap_read_active
        .globl daimos_v1584_swap_target
        .globl daimos_v1584_swap_pi2
        .globl proc_sched_cursor
''' + source)
    driver.write_text(source)

    store = root / 'storage/backstore_entry_v484.s'
    source = store.read_text()
    anchor = 'backstore_enabled: .block 1\n'
    new = anchor + '; Test-only physical v1584 overlap counters.\n'
    for name in ('snapshot_live', 'swap_started', 'swap_completed',
                 'swap_reads', 'swap_pi2', 'snapshot_pi2',
                 'swap_target', 'swap_read_active', 'last_slot'):
        sym = 'daimos_v1584_' + name
        new += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    source = replace_one(source, anchor, new, 'fixed diagnostic words')
    store.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-snapshot-swap-pi-v1584.py KERNEL_COPY')
    instrument(Path(sys.argv[1]))
    print('v1584: installed test-only scheduler/snapshot/physical PI2 witnesses')
