#!/usr/bin/env python3
"""Verify OOM cannot select an unrelated process by size."""
import os
from pathlib import Path

root = Path(os.environ['DAIMOS_REPO'])
proc = (root / 'system/kernel/proc/proc_pdp6.s').read_text()
mm = (root / 'system/kernel/mm/mm_pdp6.s').read_text()
todo = (root / 'TODO.MD').read_text()
assert 'proc_oom_select_v863:' not in proc
assert '.globl  proc_oom_select_v863' not in proc
assert 'proc_oom_scan_v863:' not in proc
assert 'mm_alloc_aligned_pressure:' in mm
assert 'pushj   17,fs_memory_reclaim' in mm
assert 'pushj   17,proc_swap_reclaim' in mm
assert 'mm_alloc_aligned_return:' in mm
assert 'Actual faulting-process termination remains OFF' in todo
print('v981: no cross-process OOM selection, normal reclaim retained: PASS')
