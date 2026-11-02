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
assert 'jumpn   1,vm_brk_fail' in brk
assert 'tlne    10,0777777' in brk
assert 'camge   5,6' in brk
assert 'mm_alloc_aligned' in brk
for code in ('MM_ERR_NOMEM,-1', 'MM_ERR_FRAGMENTED,-2',
             'MM_ERR_DESCRIPTORS,-3', 'MM_ERR_INVAL,-4', 'MM_ERR_BUSY,-5'):
    assert code in mm
assert 'mm_alloc_aligned_noreclaim' in alloc
assert 'fs_memory_reclaim' in alloc
assert 'proc_swap_reclaim' in alloc
assert 'native_sys_brk:\n        move    1,2\n        jrst    vm_space_brk_current' in syscall
assert 'proc_oom_select_v863:' not in (root / 'proc/proc_pdp6.s').read_text()
print('v998: BRK returns ambiguous -1, normal reclaim precedes failure: PASS')
print('v998: requester OOM killing remains OFF pending explicit cause classification')
