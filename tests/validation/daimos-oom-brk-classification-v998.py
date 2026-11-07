#!/usr/bin/env python3
"""Source contract: BRK rejection is not proof of physical OOM."""
import os
from pathlib import Path
root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
vm = (root / 'proc/vm_pdp6.s').read_text()
mm = (root / 'mm/mm_pdp6.s').read_text()
syscall = (root / 'proc/syscall_dispatch_pdp6.s').read_text()
brk = vm.split('vm_space_brk_current:', 1)[1].split('vm_space_destroy:', 1)[0]
alloc = mm.split('mm_alloc_aligned:', 1)[1].split('mm_free:', 1)[0]
assert 'vm_brk_fail:' in brk and 'seto    1,' in brk
assert 'jumpn   1,vm_brk_alloc_fail_v999' in brk
assert 'move    2,1                     ; exact allocator failure cause' in brk
assert 'movni   2,4                    ; local validation failure' in brk
assert 'vm_brk_fail_return_v999:' in brk
assert 'tlne    10,0777777' in brk
assert 'camge   5,6' in brk
assert 'mm_alloc_aligned' in brk
for code in ('MM_ERR_NOMEM,-1', 'MM_ERR_FRAGMENTED,-2',
             'MM_ERR_DESCRIPTORS,-3', 'MM_ERR_INVAL,-4', 'MM_ERR_BUSY,-5'):
    assert code in mm
assert 'mm_alloc_aligned_noreclaim' in alloc
assert 'fs_memory_reclaim' in alloc
assert 'proc_swap_reclaim' in alloc
assert 'native_sys_brk:\n        move    1,2\n        pushj   17,vm_space_brk_current' in syscall
expected = os.environ.get('V1283_PRODUCTION_OOM_DEFAULT', '0')
assert expected in ('0', '1'), 'invalid production OOM expectation'
assert ('.equ    PROC_OOM_BRK_ENABLED_V1000,' + expected) in syscall
assert 'native_sys_brk_check_cause_v1000:' in syscall
assert 'camn    2,[-1]' in syscall
assert 'jrst    proc_fatal_close_current_v879' in syscall
assert 'proc_oom_select_v863:' not in (root / 'proc/proc_pdp6.s').read_text()
print('v999: BRK retains internal MM cause in AC2 while AC1 stays -1: PASS')
print('v1283: production requester OOM default=' + expected +
      '; distinct BRK causes and fatal-only-on-NOMEM contract PASS')
