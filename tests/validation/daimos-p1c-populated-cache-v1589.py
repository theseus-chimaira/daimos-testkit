#!/usr/bin/env python3
"""Disposable physical D6FS cache-reclaim versus post-DMA rollback test.

Extend v1588: normal XIP userland D6FS read operations populate the
private MM-backed BCACHE slot. Observe its complete 128-word identity
at the original BCACHE reclaim boundary, then ensure no stale identity
survives through the independently scheduled BACKSTORE MM rollback.
"""

import importlib.util
from pathlib import Path
import sys


def one(text, old, new, label):
    count = text.count(old)
    assert count == 1, 'v1589 %s: %d matching anchors' % (label, count)
    return text.replace(old, new, 1)


def instrument(root):
    file = Path(__file__).with_name('daimos-p1c-postread-release-v1588.py')
    spec = importlib.util.spec_from_file_location('v1588_instrument', file)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.inject(root)

    snap = root / 'fs/memfs_snapshot_pdp6.s'
    source = snap.read_text()
    source = one(source,
                 '        setom   daimos_v1588_fault_armed\n',
                 '        setom   daimos_v1588_fault_armed\n'
                 '        pushj   17,daimos_v1589_prime_cache\n',
                 'snapshot entry physical D6FS read')
    anchor = '        .bss\n; Zero means volatile/disabled; otherwise first-block,,reserved-block-count.\n'
    helper = '''; v1589: inspect a real D6FS private cache entry built by the
; normal guest D6FS OPEN/READ operations immediately before HALT.
; Never manufacture a tag, data block or source/provider callback.
daimos_v1589_prime_cache:
        hrrz    3,bcache_state
        jumpe   3,daimos_v1589_prime_done
        movem   3,daimos_v1589_slab
        move    4,(3)
        camn    4,[-1]
        jrst    daimos_v1589_prime_done
        movem   4,daimos_v1589_key
        ; D6FS SOURCE12 (01000 class, low 6 bits mount id), BLOCK24.
        move    5,4
        lsh     5,-030
        andi    5,07700
        caie    5,01000
        jrst    daimos_v1589_prime_done
        ; Copy exact 128 cache words without touching source identity.
        movei   4,daimos_v1589_expected
        movei   5,1(3)
        hrl     4,5
        movei   5,daimos_v1589_expected+0177
        blt     4,(5)
        movei   3,0200
        movei   4,daimos_v1589_expected
daimos_v1589_prime_nonzero_loop:
        skipn   (4)
        jrst    daimos_v1589_prime_nonzero_next
        aos     daimos_v1589_nonzero
daimos_v1589_prime_nonzero_next:
        aoj     4,
        sojg    3,daimos_v1589_prime_nonzero_loop
        aos     daimos_v1589_primed
daimos_v1589_prime_done:
        popj    17,

'''
    source = one(source, anchor, helper + anchor, 'snapshot helper placement')
    source = ('''        .globl bcache_state
        .globl bcache_fetch
''' + ''.join('        .globl daimos_v1589_%s\n' % name for name in
              ('primed', 'nonzero', 'slab', 'key', 'expected'))
              + source)
    snap.write_text(source)

    swap = root / 'proc/proc_swap_pdp6.s'
    source = swap.read_text()
    source = one(source, 'daimos_v1588_capture_before:\n',
                 'daimos_v1588_capture_before:\n'
                 '        pushj   17,daimos_v1589_check_before\n',
                 'postread pre-refusal BCACHE content')
    source = one(source, 'daimos_v1588_capture_after:\n',
                 'daimos_v1588_capture_after:\n'
                 '        pushj   17,daimos_v1589_check_after\n',
                 'postread post-rollback BCACHE content')
    anchor = '; v1588 test-only witnesses, BEFORE the pin refusal becomes visible.\n'
    # The v1588 code currently has the inherited v1587 comment above its
    # capture helpers. Insert before their exact label instead.
    anchor = 'daimos_v1588_capture_before:\n'
    helper = '''; Observe stale private-cache identity after legitimate reclaim.
; AC10-AC16 are left untouched so the original rollback is unchanged.
daimos_v1589_check_before:
        movei   6,daimos_v1589_before_differences
        jrst    daimos_v1589_check_data
daimos_v1589_check_after:
        movei   6,daimos_v1589_after_differences
        push    17,6
        move    1,daimos_v1589_key
        movei   2,daimos_v1589_readback
        pushj   17,bcache_fetch     ; original, read-only private hit
        movem   1,daimos_v1589_fetch_after
        pop     17,6
        pushj   17,daimos_v1589_check_data
        movei   3,0200
        movei   4,daimos_v1589_expected
        movei   5,daimos_v1589_readback
daimos_v1589_check_fetch_loop:
        move    1,(4)
        camn    1,(5)
        jrst    daimos_v1589_check_fetch_next
        aos     daimos_v1589_fetch_differences
daimos_v1589_check_fetch_next:
        aoj     4,
        aoj     5,
        sojg    3,daimos_v1589_check_fetch_loop
        popj    17,
daimos_v1589_check_data:
        hrrz    3,bcache_state
        came    3,daimos_v1589_slab
        aos     (6)
        jumpe   3,daimos_v1589_check_data_done
        move    4,(3)
        came    4,daimos_v1589_key
        aos     (6)
        movei   4,daimos_v1589_expected
        movei   5,1(3)
        movei   3,0200
daimos_v1589_check_data_loop:
        move    1,(4)
        camn    1,(5)
        jrst    daimos_v1589_check_data_next
        aos     (6)
daimos_v1589_check_data_next:
        aoj     4,
        aoj     5,
        sojg    3,daimos_v1589_check_data_loop
daimos_v1589_check_data_done:
        popj    17,

'''
    source = one(source, anchor, helper + anchor,
                 'source-authentic private tag/full-data observer')
    source = (''.join('        .globl daimos_v1589_%s\n' % name for name in
             ('primed', 'nonzero', 'slab', 'key', 'expected', 'readback',
              'before_differences', 'after_differences', 'fetch_after',
              'fetch_differences')) + source)
    swap.write_text(source)

    cache = root / 'storage/bcache_pdp6.s'
    source = cache.read_text()
    anchor = 'bcache_reclaim:\n        push    17,010\n'
    diagnostic = '''bcache_reclaim:
        push    17,010
        ; Observe only an actual live original D6FS private cache
        ; entry. The genuine MM reclaim path decides whether it is
        ; invalidated/freed, not the observer or an injected callback.
        hrrz    4,bcache_state
        jumpe   4,daimos_v1589_reclaim_continue
        came    4,daimos_v1589_slab
        jrst    daimos_v1589_reclaim_continue
        move    5,(4)
        came    5,daimos_v1589_key
        jrst    daimos_v1589_reclaim_continue
        skipn   daimos_v1589_primed
        jrst    daimos_v1589_reclaim_continue
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1589_reclaim_continue
        aos     daimos_v1589_reclaim_matched
        setom   daimos_v1589_reclaim_inflight
        move    5,daimos_v1584_swap_started
        movem   5,daimos_v1589_reclaim_swaps
        movei   5,daimos_v1589_expected
        movei   6,1(4)
        movei   7,0200
daimos_v1589_reclaim_compare:
        move    3,(5)
        camn    3,(6)
        jrst    daimos_v1589_reclaim_next
        aos     daimos_v1589_reclaim_differences
daimos_v1589_reclaim_next:
        aoj     5,
        aoj     6,
        sojg    7,daimos_v1589_reclaim_compare
daimos_v1589_reclaim_continue:
'''
    source = one(source, anchor, diagnostic,
                 'original clean cache reclamation boundary')
    anchor = '        setzm   bcache_state\n        movei   1,1\n'
    source = one(source, anchor,
                 '        setzm   bcache_state\n'
                 '        skipn   daimos_v1589_reclaim_inflight\n'
                 '        jrst    daimos_v1589_reclaim_release_done\n'
                 '        aos     daimos_v1589_reclaim_succeeded\n'
                 '        setzm   daimos_v1589_reclaim_inflight\n'
                 'daimos_v1589_reclaim_release_done:\n'
                 '        movei   1,1\n',
                 'original successful MM free of selected cache slab')
    anchor = 'bcache_reclaim_none:\n        setz    1,\n'
    source = one(source, anchor,
                 'bcache_reclaim_none:\n'
                 '        skipn   daimos_v1589_reclaim_inflight\n'
                 '        jrst    daimos_v1589_reclaim_none_done\n'
                 '        aos     daimos_v1589_reclaim_refused\n'
                 '        setzm   daimos_v1589_reclaim_inflight\n'
                 'daimos_v1589_reclaim_none_done:\n'
                 '        setz    1,\n',
                 'original BCACHE/MM reclaim refusal')
    source = (''.join('        .globl daimos_v1589_%s\n' % name
                       for name in ('primed', 'slab', 'key', 'expected',
                                    'reclaim_matched', 'reclaim_inflight',
                                    'reclaim_swaps', 'reclaim_differences',
                                    'reclaim_succeeded', 'reclaim_refused'))
              + '        .globl daimos_v1584_snapshot_live\n'
                '        .globl daimos_v1584_swap_started\n' + source)
    cache.write_text(source)

    store = root / 'storage/backstore_entry_v484.s'
    source = store.read_text()
    anchor = 'daimos_v1588_in_request: .block 1\n'
    additions = ''
    for name in ('primed', 'nonzero', 'slab', 'key',
                 'before_differences', 'after_differences',
                 'fetch_after', 'fetch_differences', 'reclaim_matched',
                 'reclaim_inflight', 'reclaim_swaps', 'reclaim_differences',
                 'reclaim_succeeded', 'reclaim_refused'):
        symbol = 'daimos_v1589_' + name
        additions += '        .globl %s\n%s: .block 1\n' % (symbol, symbol)
    for name in ('expected', 'readback'):
        symbol = 'daimos_v1589_' + name
        additions += '        .globl %s\n%s: .block 0200\n' % (symbol, symbol)
    source = one(source, anchor, anchor + additions,
                 'temporary exact physical block witnesses')
    store.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-populated-cache-v1589.py KERNEL')
    instrument(Path(sys.argv[1]))
    print('v1589: real D6FS private-cache MM reclaim during post-DMA rollback')
