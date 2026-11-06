#!/usr/bin/env python3
"""Read-only swap and slot snapshot at the physical BRK OOM decision.

Only the disposable kernel is changed. The v1205 real process/MM
snapshot remains on the same synchronous OOM path and precedes this
test-only observation of genuine disk-swap backing and slot capacity.
"""

from pathlib import Path
import sys

p = Path(sys.argv[1]) / 'proc/syscall_dispatch_pdp6.s'
source = p.read_text()
anchor = ('daimos_f07p_done_v1205:\n'
          '        move    6,fs_provider_ready')
assert source.count(anchor) == 1, 'v1207: v1205 snapshot completion moved'
source = source.replace(anchor, '''daimos_f07p_done_v1205:
        aos     daimos_f07s_samples_v1207
        move    7,proc_swap_blocks_used
        movem   7,daimos_f07s_swap_blocks_v1207
        move    7,proc_slots
        movem   7,daimos_f07s_slot_capacity_v1207
        move    7,backstore_enabled
        movem   7,daimos_f07s_swap_active_v1207
        ; Capture watermark maxima at this same OOM decision, not
        ; after teardown (which would mix different peak instants).
        move    7,proc_stack_highwater
        movem   7,daimos_f07s_stack_peak_v1207
        move    7,kernel_idle_stack_highwater
        movem   7,daimos_f07s_idle_peak_v1207
        move    6,fs_provider_ready''', 1)
source = '''        .globl proc_swap_blocks_used
        .globl proc_slots
        .globl backstore_enabled
        .globl proc_stack_highwater
        .globl kernel_idle_stack_highwater
''' + source
source += '\n        .bss\n'
for label in ('samples', 'error', 'swap_blocks', 'slot_capacity',
              'swap_active', 'stack_peak', 'idle_peak'):
    sym = 'daimos_f07s_%s_v1207' % label
    source += '        .globl %s\n%s: .block 1\n' % (sym, sym)

# v1209 diagnosis is never linked into production. These zero-initialized
# words live in the disposable KCORE BSS and can be examined even if the
# simulator cannot return normally from the stalled guest. No extra
# register, process-table word, or private-stack entry is allocated.
probes = (
    ('pressure', 'proc_swap_service_pressure:'),
    ('fallback', 'proc_swap_service_reclaim_v1208:'),
    ('victim_search', 'proc_swap_reclaim_loop:'),
    ('reclaim_ok', '        jrst    proc_swap_reclaim_done\n'),
    ('reclaim_fail', 'proc_swap_reclaim_fail:'),
    ('swapout_ok', '        jrst    proc_swap_out_restore\n'),
    ('swapout_fail', 'proc_swap_out_fail:'),
    ('swapin_ok', '        sub     17,kconst_1_1\n'
                  '        setz    1,\n'
                  '        jrst    proc_swap_in_restore\n'),
    ('swapin_pressure', 'proc_swap_in_pressure:'),
    ('swapin_fail', 'proc_swap_in_fail:'),
    ('cooldown', 'proc_swap_service_cooldown_v833:'),
    ('exchanged', 'proc_swap_service_exchanged_v834:'),
    ('restored', 'proc_swap_service_restore_done_v842:'),
)
for label, _ in probes:
    sym = 'daimos_f07s_%s_v1209' % label
    source += '        .globl %s\n%s: .block 1\n' % (sym, sym)
p.write_text(source)

swap_path = Path(sys.argv[1]) / 'proc/proc_swap_pdp6.s'
swap_source = swap_path.read_text()
for label, anchor in probes:
    assert swap_source.count(anchor) == 1, \
        'v1209: swap probe moved or ambiguous: ' + label
    # For branch-target labels the counter runs at entry. For the three
    # unique return jumps insert the count immediately before the jump;
    # the final result register AC1 remains unchanged.
    increment = '        aos     daimos_f07s_%s_v1209\n' % label
    if anchor.endswith(':'):
        swap_source = swap_source.replace(anchor, anchor + '\n' +
                                          increment.rstrip('\n'), 1)
    else:
        swap_source = swap_source.replace(anchor, increment + anchor, 1)
swap_source = ''.join('        .globl daimos_f07s_%s_v1209\n' % label
                      for label, _ in probes) + swap_source
swap_path.write_text(swap_source)
