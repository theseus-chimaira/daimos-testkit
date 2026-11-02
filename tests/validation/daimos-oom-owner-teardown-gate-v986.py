#!/usr/bin/env python3
"""Guard the unresolved owner-only fatal teardown OOM safety contract."""
import os
from pathlib import Path
root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
proc = (root / 'proc/proc_pdp6.s').read_text()
mm = (root / 'mm/mm_pdp6.s').read_text()
start = proc.index('proc_fatal_close_current_v879:\n')
end = proc.index('proc_fatal_close_no_owner_v879:\n', start)
owner = proc[start:end]
assert 'pushj   17,file_close_all' in owner
assert 'jumpn   1,proc_fatal_close_sleep_fail_v885' in owner
assert 'pushj   17,proc_sleep_ticks' in owner
assert 'caige   1,01000' in owner
assert 'jrst    proc_fatal_close_retry_v879' in owner
assert 'jrst    proc_exit_current' in owner
assert 'proc_fatal_close_retry_v879:' in owner
assert 'mm_free' not in owner
assert 'proc_oom_select_v863:' not in proc
assert 'pushj   17,proc_swap_reclaim' in mm
assert 'pushj   17,fs_memory_reclaim' in mm
print('v986: private owner FILE retry and capped backoff preserved: PASS')
print('v986: retry is unbounded in count, provider liveness NOT CERTIFIED')
print('v986: forced OOM termination remains disabled')
