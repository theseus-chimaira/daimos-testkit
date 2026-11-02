#!/usr/bin/env python3
"""Guard requester-only failed BRK without enabling forced termination."""
import os
from pathlib import Path
p=Path(os.environ['DAIMOS_REPO'])/'system/kernel/proc/vm_pdp6.s'
s=p.read_text()
assert 'vm_brk_full_alloc:' in s
part=s.split('vm_brk_full_alloc:',1)[1].split('vm_brk_commit:',1)[0]
assert 'move    4,proc_current_slot' in part
assert 'pushj   17,mm_alloc_aligned' in part
assert 'jumpn   1,vm_brk_fail' in part
assert 'proc_oom_select_v863' not in part
print('v982: BRK allocation failure remains requester-local and nonlethal: PASS')
