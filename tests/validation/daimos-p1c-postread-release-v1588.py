#!/usr/bin/env python3
"""Disposable checked BACKSTORE release refusal after real swap READ DMA.

Reuse the v1587 exact transaction-boundary observer, but move its
failure injection from the MM pin to the BACKSTORE release entry.
The real MM allocation, pin/unpin, complete mapped physical READ,
original MM rollback, and owner/BCACHE paths remain production code.
"""

import importlib.util
from pathlib import Path
import sys


def replace_one(source, old, new, label):
    count = source.count(old)
    assert count == 1, '%s: expected one anchor, got %d' % (label, count)
    return source.replace(old, new, 1)


def inject(root):
    injector = Path(__file__).with_name('daimos-p1c-pin-rollback-v1587.py')
    spec = importlib.util.spec_from_file_location('v1587_pin_instrument', injector)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.instrument(root)

    for relative in ('fs/memfs_snapshot_pdp6.s',
                     'proc/proc_swap_pdp6.s',
                     'storage/backstore_entry_v484.s'):
        file = root / relative
        content = file.read_text()
        assert 'daimos_v1587_' in content
        file.write_text(content.replace('daimos_v1587_', 'daimos_v1588_')
                        .replace('pin_refusals', 'release_refusals'))

    swap = root / 'proc/proc_swap_pdp6.s'
    text = swap.read_text()
    start = ('        move    1,(17)\n'
             '        skipn   daimos_v1588_fault_armed\n')
    end = ('daimos_v1588_pin_regular:\n'
           '        pushj   17,mm_pin\n'
           '        jumpn   1,proc_swap_in_pin_fail\n')
    assert text.count(start) == 1 and text.count(end) == 1
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before + ('        move    1,(17)\n'
                     '        pushj   17,mm_pin\n'
                     '        jumpn   1,proc_swap_in_pin_fail\n') + after

    old = ('''        move    1,15
        move    2,16
        pushj   17,backstore_free
        jumpn   1,proc_swap_in_free_fail
''')
    new = ('''        ; Only on the first original independently selected
        ; slot-0 swap READ completed during snapshot, capture exact
        ; post-I/O/pre-release state for test-only refusal.
        skipn   daimos_v1588_fault_armed
        jrst    daimos_v1588_release_normal
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1588_release_normal
        move    5,proc_sched_cursor
        trnn    5,0400
        jrst    daimos_v1588_release_normal
        move    1,(17)
        pushj   17,daimos_v1588_capture_before
        setom   daimos_v1588_in_request
daimos_v1588_release_normal:
        move    1,15
        move    2,16
        pushj   17,backstore_free
        setzm   daimos_v1588_in_request
        jumpn   1,proc_swap_in_free_fail
''')
    text = replace_one(text, old, new, 'original post-DMA backing release')
    text = ('        .globl daimos_v1588_in_request\n' + text)
    swap.write_text(text)

    # Test-only returned refusal at the actual original provider entry.
    # Other release calls pass through the unchanged implementation.
    provider = root / 'storage/backstore.s'
    content = provider.read_text()
    old = ('backstore_free:\n'
           '        push    17,1\n')
    new = ('''backstore_free:
        skipn   daimos_v1588_fault_armed
        jrst    daimos_v1588_release_provider_normal
        skipn   daimos_v1588_in_request
        jrst    daimos_v1588_release_provider_normal
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1588_release_provider_normal
        setzm   daimos_v1588_fault_armed
        aos     daimos_v1588_release_refusals
        seto    1,                  ; controlled checked release refusal
        popj    17,
daimos_v1588_release_provider_normal:
        push    17,1
''')
    content = replace_one(content, old, new, 'production checked-release entry')
    content = ('''        .globl daimos_v1588_fault_armed
        .globl daimos_v1588_in_request
        .globl daimos_v1588_release_refusals
        .globl daimos_v1584_snapshot_live
''' + content)
    provider.write_text(content)

    entry = root / 'storage/backstore_entry_v484.s'
    content = entry.read_text()
    old = 'daimos_v1588_bitmap_copy: .block 0100\n'
    new = old + ('        .globl daimos_v1588_in_request\n'
                 'daimos_v1588_in_request: .block 1\n')
    content = replace_one(content, old, new, 'postread provider marker')
    entry.write_text(content)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-postread-release-v1588.py KERNEL')
    inject(Path(sys.argv[1]))
    print('v1588: one post-DMA checked-release refusal, real MM rollback')
