#!/usr/bin/env python3
"""Disposable pre-I/O MM-pin refusal during real PI6 snapshot overlap.

Only one pin call for an already allocated slot-0 swap-in is refused.
The original proc_swap_in_pin_fail -> mm_free -> transition unlock path
must execute. All original MM, BACKSTORE, scheduler, FS and BCACHE code
is left unchanged. Snapshot before/after witnesses at the transaction
boundary, before a later TERM event can legitimately release backing.
"""

from pathlib import Path
import sys


def once(src, old, new, what):
    count = src.count(old)
    assert count == 1, 'v1587 %s: source count %d' % (what, count)
    return src.replace(old, new, 1)


WORDS = (
    'fault_armed', 'pin_refusals', 'rollback_count', 'term_events',
    'slot', 'allocated_base', 'mm_before', 'mm_after',
    'owner_before', 'owner_after', 'backing_before', 'backing_after',
    'bitmap_words', 'bitmap_differences', 'record_before', 'record_after',
    'process_before', 'process_after', 'process_word1_before',
    'process_word1_after', 'process_word2_before', 'process_word2_after',
    'bcache_state_before', 'bcache_state_after',
    'bcache_tag_before', 'bcache_tag_after',
    'bcache_private_before', 'bcache_private_after',
    'storage_expect_after', 'extent_still_present',
)


def instrument(root):
    snapshot = root / 'fs/memfs_snapshot_pdp6.s'
    text = snapshot.read_text()
    anchor = '        pushj   17,daimos_v1585_timer_arm\n'
    text = once(text, anchor,
                '        setom   daimos_v1587_fault_armed\n' + anchor,
                'snapshot fault arm')
    snapshot.write_text('        .globl daimos_v1587_fault_armed\n' + text)

    cache = root / 'storage/bcache_pdp6.s'
    text = cache.read_text()
    text = once(text, '        .globl  bcache_fetch\n',
                '        .globl  bcache_state\n'
                '        .globl  bcache_workspace_tag\n'
                '        .globl  bcache_fetch\n', 'BCACHE observability')
    cache.write_text(text)

    swap = root / 'proc/proc_swap_pdp6.s'
    text = swap.read_text()
    anchor = ('        move    1,(17)\n'
              '        pushj   17,mm_pin\n'
              '        jumpn   1,proc_swap_in_pin_fail\n')
    replacement = '''        move    1,(17)
        skipn   daimos_v1587_fault_armed
        jrst    daimos_v1587_pin_regular
        skipn   daimos_v1584_snapshot_live
        jrst    daimos_v1587_pin_regular
        move    5,proc_sched_cursor
        trnn    5,0400                ; real slot-0 swap service only
        jrst    daimos_v1587_pin_regular
        setzm   daimos_v1587_fault_armed
        pushj   17,daimos_v1587_capture_before
        aos     daimos_v1587_pin_refusals
        ; Test-only MM_ERR_BUSY. The actual MM allocator has already
        ; allocated VM; its original pin/refusal rollback is exercised.
        movni   1,5
        jrst    proc_swap_in_pin_fail
daimos_v1587_pin_regular:
        pushj   17,mm_pin
        jumpn   1,proc_swap_in_pin_fail
'''
    text = once(text, anchor, replacement, 'real MM pin call')
    anchor = ('        movem   1,(11)\n'
              '        jrst    proc_swap_in_fail\n'
              'proc_swap_in_alloc_status:\n')
    text = once(text, anchor, '''        movem   1,(11)
        skipn   daimos_v1587_pin_refusals
        jrst    proc_swap_in_fail
        skipn   daimos_v1587_rollback_count
        jrst    daimos_v1587_first_rollback
        jrst    proc_swap_in_fail
daimos_v1587_first_rollback:
        pushj   17,daimos_v1587_capture_after
        aos     daimos_v1587_rollback_count
        jrst    proc_swap_in_fail
proc_swap_in_alloc_status:
''', 'original post-MM-free rollback')
    anchor = ('proc_swap_service_failed_event_v1507:\n'
              '        movei   2,SYS_EVENT_TERM\n')
    text = once(text, anchor, '''proc_swap_service_failed_event_v1507:
        skipn   daimos_v1587_rollback_count
        jrst    daimos_v1587_term_normal
        came    1,daimos_v1587_slot
        jrst    daimos_v1587_term_normal
        aos     daimos_v1587_term_events
daimos_v1587_term_normal:
        movei   2,SYS_EVENT_TERM
''', 'original TERM refusal event')

    anchor = ('/* An impossible late mode mismatch must not release a partially committed\n')
    helpers = '''; v1587 test-only witnesses, BEFORE the pin refusal becomes visible.
; AC10..AC16 remain untouched; original swap-in saves those registers.
daimos_v1587_capture_before:
        movem   1,daimos_v1587_allocated_base
        movem   10,daimos_v1587_slot
        move    3,mm_extent_count
        movem   3,daimos_v1587_mm_before
        move    3,proc_swap_blocks_used
        movem   3,daimos_v1587_owner_before
        move    3,backstore_blocks_used
        movem   3,daimos_v1587_backing_before
        move    3,(12)
        movem   3,daimos_v1587_record_before
        move    3,(11)
        movem   3,daimos_v1587_process_before
        move    3,1(11)
        movem   3,daimos_v1587_process_word1_before
        move    3,2(11)
        movem   3,daimos_v1587_process_word2_before
        move    3,bcache_state
        movem   3,daimos_v1587_bcache_state_before
        move    3,bcache_workspace_tag
        movem   3,daimos_v1587_bcache_tag_before
        setz    3,
        skipn   4,bcache_state
        jrst    daimos_v1587_before_bcache_saved
        hrrz    4,4
        move    3,(4)
daimos_v1587_before_bcache_saved:
        movem   3,daimos_v1587_bcache_private_before
        ; Inspect the EXACT backing allocation bitmap; not only its
        ; count or a checksum. Capacity is 0100 octal words (64).
        move    3,backstore_blocks
        addi    3,043
        idivi   3,044
        movem   3,daimos_v1587_bitmap_words
        caile   3,0100
        jrst    proc_swap_storage_invariant_v30
        move    4,backstore_bitmap
        movei   5,daimos_v1587_bitmap_copy
daimos_v1587_before_bitmap_loop:
        jumpe   3,daimos_v1587_before_done
        move    6,(4)
        movem   6,(5)
        aoj     4,
        aoj     5,
        sojg    3,daimos_v1587_before_bitmap_loop
daimos_v1587_before_done:
        popj    17,

; Test-only after-state runs immediately after REAL mm_free and original
; transition unlock, before the scheduler can TERM the failed owner.
daimos_v1587_capture_after:
        move    3,mm_extent_count
        movem   3,daimos_v1587_mm_after
        move    3,proc_swap_blocks_used
        movem   3,daimos_v1587_owner_after
        move    3,backstore_blocks_used
        movem   3,daimos_v1587_backing_after
        move    3,(12)
        movem   3,daimos_v1587_record_after
        move    3,(11)
        movem   3,daimos_v1587_process_after
        move    3,1(11)
        movem   3,daimos_v1587_process_word1_after
        move    3,2(11)
        movem   3,daimos_v1587_process_word2_after
        move    3,bcache_state
        movem   3,daimos_v1587_bcache_state_after
        move    3,bcache_workspace_tag
        movem   3,daimos_v1587_bcache_tag_after
        setz    3,
        skipn   4,bcache_state
        jrst    daimos_v1587_after_bcache_saved
        hrrz    4,4
        move    3,(4)
daimos_v1587_after_bcache_saved:
        movem   3,daimos_v1587_bcache_private_after
        move    3,daimos_v1587_bitmap_words
        move    4,backstore_bitmap
        movei   5,daimos_v1587_bitmap_copy
daimos_v1587_after_bitmap_loop:
        jumpe   3,daimos_v1587_after_bitmap_done
        move    6,(4)
        camn    6,(5)
        jrst    daimos_v1587_after_bitmap_equal
        aos     daimos_v1587_bitmap_differences
daimos_v1587_after_bitmap_equal:
        aoj     4,
        aoj     5,
        sojg    3,daimos_v1587_after_bitmap_loop
daimos_v1587_after_bitmap_done:
        ; The newly allocated base must be ABSENT from the actual MM
        ; extent table after original mm_free, not merely unpinned.
        move    3,mm_extent_count
        movei   4,mm_extents
daimos_v1587_after_mm_scan:
        jumpe   3,daimos_v1587_after_mm_done
        hrrz    5,(4)
        came    5,daimos_v1587_allocated_base
        jrst    daimos_v1587_after_mm_next
        aos     daimos_v1587_extent_still_present
daimos_v1587_after_mm_next:
        addi    4,2
        sojg    3,daimos_v1587_after_mm_scan
daimos_v1587_after_mm_done:
        move    1,10
        movei   2,1                  ; DISK must still be authoritative
        pushj   17,proc_storage_expect_v30
        movem   1,daimos_v1587_storage_expect_after
        popj    17,

'''
    text = once(text, anchor, helpers + anchor,
                'test-only MM/BCACHE/backing witnesses')
    prefix = ''.join('        .globl daimos_v1587_%s\n' % name
                     for name in WORDS)
    prefix += ('        .globl daimos_v1584_snapshot_live\n'
               '        .globl mm_extent_count\n'
               '        .globl mm_extents\n'
               '        .globl backstore_bitmap\n'
               '        .globl backstore_blocks_used\n'
               '        .globl backstore_blocks\n'
               '        .globl proc_swap_blocks_used\n'
               '        .globl bcache_state\n'
               '        .globl bcache_workspace_tag\n')
    swap.write_text(prefix + text)

    backing = root / 'storage/backstore_entry_v484.s'
    text = backing.read_text()
    anchor = 'backstore_enabled: .block 1\n'
    addition = '; v1587 disposable exact rollback witnesses.\n'
    addition += ''.join('        .globl daimos_v1587_%s\n'
                        'daimos_v1587_%s: .block 1\n' % (name, name)
                        for name in WORDS)
    addition += ('        .globl daimos_v1587_bitmap_copy\n'
                 'daimos_v1587_bitmap_copy: .block 0100\n')
    text = once(text, anchor, anchor + addition,
                'test-only snapshot words')
    backing.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-pin-rollback-v1587.py KERNEL_COPY')
    instrument(Path(sys.argv[1]))
    print('v1587: one synthetic MM pin refusal; original MM/free/owner rollback')
