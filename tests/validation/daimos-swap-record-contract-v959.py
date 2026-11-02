#!/usr/bin/env python3
"""v959: PDP-6 process swap record publication and lifetime contract.

Source guard: freezes stage order without interpreting a resident executable
record as a disk allocation. Not a dynamic corruption-recovery proof.
"""
from pathlib import Path
import sys
root = Path(sys.argv[1])
asm = (root/'system/kernel/proc/proc_swap_pdp6.s').read_text()
c = (root/'system/kernel/proc/vm_pdp6_swap.c').read_text()
attach = (root/'system/kernel/proc/proc_pure_attach.c').read_text()

def fragment(source, first, last):
    assert source.count(first) == 1, ('ambiguous', first)
    return source.split(first, 1)[1].split(last, 1)[0]

def order(source, *items):
    offset = -1
    for item in items:
        pos = source.find(item, offset + 1)
        assert pos >= 0, ('missing or unordered', item)
        offset = pos

out = fragment(asm, '\nproc_swap_out:', '\nproc_swap_out_unpin:')
inp = fragment(asm, '\nproc_swap_in:', '\nproc_swap_in_read_fail:')
failout = fragment(asm, '\nproc_swap_out_unpin:', '\nproc_swap_out_restore:')
failin = fragment(asm, '\nproc_swap_in_read_fail:', '\nproc_swap_in_alloc_status:')
detach = fragment(c, '\nproc_swap_detach(int slot)', '\n/** Pin, write')

# This is one multiplexed record, not a standalone disk-span descriptor.
order(attach, 'packed = VFS_INDEX(backing);',
      'packed |= (kword_t)((mount - 1U)',
      'proc_swap_records[slot].state = packed;')
assert 'if (VM_PDP6_BASE(p) == 0UL && state != 0UL)' in detach
order(detach, 'backstore_verify_allocated_v795(first, blocks)',
      'backstore_free(first, blocks);', 'proc_swap_blocks_used -= blocks;',
      'proc_swap_records[slot].state = 0UL;')

# On swap-out, the old resident record is saved in the owning u-area,
# physical VM is released before the one-word disk descriptor is published.
order(out, 'movem   16,PROC_SWAP_BACKING_OFFSET(1)',
      'pushj   17,mm_unpin', 'pushj   17,mm_free',
      'hllzs   1(11)', 'movem   1,(12)',
      'addm    15,proc_swap_blocks_used',
      'pushj   17,proc_storage_publish_v30',
      'andcmi  1,PROC_TRANSITION_RH')
assert 'jumpn   1,proc_swap_out_record_fail' in out
order(failout, 'pushj   17,mm_unpin',
      'jumpn   1,proc_swap_storage_invariant_v30',
      'proc_swap_out_record_fail:', 'pushj   17,backstore_free',
      'setzm   PROC_SWAP_BACKING_OFFSET(1)',
      'proc_swap_out_clear:')

# On swap-in, keep the disk record until the reload and unpin succeed,
# then publish the restored resident backing record and new storage mode.
order(inp, 'pushj   17,backstore_read', 'pushj   17,mm_unpin',
      'hrrm    1,1(11)', 'addm    1,proc_swap_blocks_used',
      'pushj   17,backstore_free', 'movem   14,(12)',
      'setzm   PROC_SWAP_BACKING_OFFSET(1)',
      'pushj   17,proc_storage_publish_v30',
      'andcmi  1,PROC_TRANSITION_RH')
assert failin.count('jumpn   1,proc_swap_storage_invariant_v30') == 3
assert 'jrst    proc_swap_in_drop_local' in failin
print('v959: resident/disk record staging, validation, commit, rollback PASS')
