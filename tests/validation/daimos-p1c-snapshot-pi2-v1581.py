#!/usr/bin/env python3
"""Select actual Type-236 PI2 completion for the first MEMFS HALT header.

Inject only in disposable DAIMOS source copied by the full guest runner.
No simulated failure return is written to the BACKSTORE gateway: the real
drum DMA must first reach its hardware DONE interrupt, then the original
PI2 driver reports the selected descriptor as failed to the original owner.
"""

from pathlib import Path
import sys


def change(source, old, new, name):
    if source.count(old) != 1:
        raise AssertionError('v1581 source anchor drift: ' + name)
    return source.replace(old, new, 1)


def inject(root):
    bridge = root / 'fs/fs_mres.s'
    driver = root / 'drivers/drm236_io.s'
    kernel = root / 'storage/backstore_entry_v484.s'

    source = bridge.read_text()
    original = ('backstore_write:\n'
                'blockset_direct_tail_write:\n'
                '        movei   4,1\n')
    changed = '''backstore_write:
blockset_direct_tail_write:
        ; v1581: select only the first snapshot INVALID header write.
        ; The original backing transfer executes in full, including DMA.
        skipn   proc_swap_blocks_used
        jrst    daimos_v1581_write_continue
        move    0,backstore_blocks
        subi    0,1
        came    1,0
        jrst    daimos_v1581_write_continue
        caie    2,1
        jrst    daimos_v1581_write_continue
        skipn   (3)
        jrst    daimos_v1581_arm_write
        jrst    daimos_v1581_write_continue
daimos_v1581_arm_write:
        setom   daimos_v1581_arm
        movem   1,daimos_v1581_relative
daimos_v1581_write_continue:
        movei   4,1
'''
    source = change(source, original, changed, 'BACKSTORE write selector')
    source = ('''        .globl proc_swap_blocks_used
        .globl backstore_blocks
        .globl daimos_v1581_arm
        .globl daimos_v1581_relative
''' + source)
    bridge.write_text(source)

    source = driver.read_text()
    original = ('        add     017,kconst_3_3\n'
                '        pushj   017,storage_request_init\n\n'
                'drm236_runtime_retry:\n')
    changed = '''        add     017,kconst_3_3
        pushj   017,storage_request_init
        ; v1581: bind one genuine physical WRITE descriptor, not its
        ; caller's address or a synthetic completion status.
        skipn   daimos_v1581_arm
        jrst    drm236_runtime_retry
        setzm   daimos_v1581_arm
        ; PUSHJ advances AC17 inside storage_request_init; after the
        ; call the caller's three words are -2, -1, 0, not -3,-2,-1.
        move    5,-1(017)
        caie    5,0220
        jrst    drm236_runtime_retry
        movei   5,-2(017)
        movem   5,daimos_v1581_target_descriptor
        hlrz    5,-2(017)
        movem   5,daimos_v1581_target_group

drm236_runtime_retry:
'''
    source = change(source, original, changed, 'physical request descriptor')
    original = ('        trnn    1,DRM_DR_DONE\n'
                '        jrst    pdp10_pi_dispatch_done\n'
                '        cono    0400,DRM_DR_DESELECT\n')
    changed = '''        trnn    1,DRM_DR_DONE
        jrst    pdp10_pi_dispatch_done
        ; v1581: only the genuine Type-236 DONE for the selected
        ; descriptor is redirected into the production PI2 error leaf.
        hrrz    2,drm236_active_request
        jumpe   2,daimos_v1581_pi_normal
        came    2,daimos_v1581_target_descriptor
        jrst    daimos_v1581_pi_normal
        setzm   daimos_v1581_target_descriptor
        aos     daimos_v1581_pi2_errors
        jrst    drm236_pi_error
daimos_v1581_pi_normal:
        cono    0400,DRM_DR_DESELECT
'''
    source = change(source, original, changed, 'real Type-236 PI2 DONE')
    source = ('''        .globl daimos_v1581_arm
        .globl daimos_v1581_target_descriptor
        .globl daimos_v1581_target_group
        .globl daimos_v1581_pi2_errors
''' + source)
    driver.write_text(source)

    source = kernel.read_text()
    anchor = 'backstore_enabled: .block 1\n'
    new = (anchor + '''; Test-only v1581 five fixed witnesses, no production RAM cost.
        .globl daimos_v1581_arm
        .globl daimos_v1581_relative
        .globl daimos_v1581_target_descriptor
        .globl daimos_v1581_target_group
        .globl daimos_v1581_pi2_errors
daimos_v1581_arm: .block 1
daimos_v1581_relative: .block 1
daimos_v1581_target_descriptor: .block 1
daimos_v1581_target_group: .block 1
daimos_v1581_pi2_errors: .block 1
''')
    source = change(source, anchor, new, 'KCORE diagnostic witnesses')
    kernel.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-snapshot-pi2-v1581.py KERNEL_COPY')
    inject(Path(sys.argv[1]))
    print('v1581: armed one actual Type-236 PI2 snapshot-header WRITE error')
