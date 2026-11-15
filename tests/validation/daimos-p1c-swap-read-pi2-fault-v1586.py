#!/usr/bin/env python3
"""Test-only real Type-236 DR_DONE error on independently scheduled swap READ.

Run AFTER the v1584 PI2 observer and v1585 PI6 timer observer, only in
a disposable source tree. Select the first original slot-0 swap-READ
descriptor that actually completes DR_DONE during MEMFS snapshot.
Redirect its real PI2 completion into the original DRM error leaf;
do not change a BACKSTORE syscall result or fabricate a scheduler PI.
"""

from pathlib import Path
import sys


def replace(source, old, new, label):
    assert source.count(old) == 1, '%s: source anchor count=%d' % (
        label, source.count(old))
    return source.replace(old, new, 1)


def inject(root):
    snapshot = root / 'fs/memfs_snapshot_pdp6.s'
    source = snapshot.read_text()
    anchor = '        pushj   17,daimos_v1585_timer_arm\n'
    source = replace(source, anchor, anchor +
                     '        setom   daimos_v1586_fault_armed\n',
                     'snapshot entry arms one swap PI2')
    snapshot.write_text('        .globl daimos_v1586_fault_armed\n' + source)

    driver = root / 'drivers/drm236_io.s'
    source = driver.read_text()
    anchor = '        movem   5,daimos_v1584_swap_target\n\n'
    source = replace(source, anchor,
                     '        movem   5,daimos_v1584_swap_target\n'
                     '        ; Capture the actual selected DR group from the\n'
                     '        ; original DMA descriptor at -2(017).\n'
                     '        hlrz    5,-2(017)\n'
                     '        movem   5,daimos_v1586_target_group\n\n',
                     'original swap READ descriptor')
    anchor = ('        aos     daimos_v1584_swap_pi2\n'
              '        setzm   daimos_v1584_swap_target\n'
              'daimos_v1584_dr_done_normal:\n')
    replacement = ('''        aos     daimos_v1584_swap_pi2
        setzm   daimos_v1584_swap_target
        ; The original physical DR_DONE, not a fake return/error.
        ; Only the first real independently scheduled swap READ fails.
        skipn   daimos_v1586_fault_armed
        jrst    daimos_v1584_dr_done_normal
        setzm   daimos_v1586_fault_armed
        aos     daimos_v1586_fault_count
        jrst    drm236_pi_error
daimos_v1584_dr_done_normal:
''')
    source = replace(source, anchor, replacement,
                     'authentic swap-READ DR_DONE PI2 fault')
    driver.write_text(('        .globl daimos_v1586_fault_armed\n'
                         '        .globl daimos_v1586_fault_count\n'
                         '        .globl daimos_v1586_target_group\n' + source))

    store = root / 'storage/backstore_entry_v484.s'
    source = store.read_text()
    anchor = 'daimos_v1585_end_tick: .block 1\n'
    additions = ''
    for name in ('fault_armed', 'fault_count', 'target_group'):
        symbol = 'daimos_v1586_' + name
        additions += '        .globl %s\n%s: .block 1\n' % (
            symbol, symbol)
    source = replace(source, anchor, anchor + additions,
                     'swap-READ PI2 physical witnesses')
    store.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-swap-read-pi2-fault-v1586.py KERNEL')
    inject(Path(sys.argv[1]))
    print('v1586: selected one real slot-0 swap READ DR_DONE as fatal PI2')
