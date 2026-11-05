#!/usr/bin/env python3
"""Only in a disposable PDP-6 kernel, expose existing MM/clock counters.

The five reserved BRK test selectors are used solely by the v1151
endurance userland fixture. Ordinary BRK requests, allocation errors,
owner selection, and process teardown all use original production code.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])
dispatch = root / 'proc/syscall_dispatch_pdp6.s'
source = dispatch.read_text()
anchor = '''native_sys_brk:
        move    1,2
        pushj   17,vm_space_brk_current'''
replacement = '''native_sys_brk:
        ; v1151 test-only readonly probes into the real MM and PI6 words.
        ; All ordinary physical BRK requests follow the original path.
        camn    2,[0777770]
        jrst    daimos_test_mm_extents_v1151
        camn    2,[0777771]
        jrst    daimos_test_swap_blocks_v1151
        camn    2,[0777772]
        jrst    daimos_test_pi6_ticks_v1151
        camn    2,[0777773]
        jrst    daimos_test_physical_count_v1151
        camn    2,[0777774]
        jrst    daimos_test_bcache_base_v1151
        jrst    daimos_test_brk_real_v1151
daimos_test_mm_extents_v1151:
        move    1,mm_extent_count
        popj    17,
daimos_test_swap_blocks_v1151:
        move    1,proc_swap_blocks_used
        popj    17,
daimos_test_pi6_ticks_v1151:
        move    1,proc_timer_clock
        popj    17,
daimos_test_physical_count_v1151:
        move    1,daimos_test_phys_oom_count_v1151
        popj    17,
daimos_test_bcache_base_v1151:
        hrrz    1,bcache_state
        popj    17,
daimos_test_brk_real_v1151:
        move    1,2
        pushj   17,vm_space_brk_current
        camn    1,[-1]
        jrst    daimos_test_brk_error_v1151
        jrst    daimos_test_brk_return_v1151
daimos_test_brk_error_v1151:
        camn    2,[-1]                ; actual physical-MM failure only
        aos     daimos_test_phys_oom_count_v1151
daimos_test_brk_return_v1151:'''
assert source.count(anchor) == 1, 'v1151: BRK entry changed'
dispatch.write_text('''        .globl mm_extent_count
        .globl proc_swap_blocks_used
        .globl proc_timer_clock
        .globl bcache_state
''' + source.replace(anchor, replacement, 1) + '''
        .bss
        .globl daimos_test_phys_oom_count_v1151
daimos_test_phys_oom_count_v1151: .block 1
''')

proc = root / 'proc/proc_pdp6.s'
source = proc.read_text()
anchor = 'proc_timer_clock:\n        .block 1\n'
assert source.count(anchor) == 1, 'v1151: PI6 timer layout changed'
proc.write_text('        .globl proc_timer_clock\n' + source)

# A clean BCACHE slab is a deliberately reclaimable 0201-word MM extent
# with owner 6. It is created on the next userland FILE read and freed
# on physical pressure. Total MM extent count is therefore not a leak
# metric unless the slab's current presence is subtracted explicitly.
cache = root / 'storage/bcache_pdp6.s'
source = cache.read_text()
anchor = 'bcache_state:    .block 1\n'
assert source.count(anchor) == 1, 'v1151: BCACHE layout changed'
cache.write_text(source.replace(anchor, '        .globl bcache_state\n' +
                                anchor, 1))
