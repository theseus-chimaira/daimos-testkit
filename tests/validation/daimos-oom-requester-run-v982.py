#!/usr/bin/env python3
"""Check RUN MM failure discards unpublished child, not requesting parent."""
import os
from pathlib import Path
src=(Path(os.environ['DAIMOS_REPO'])/'system/kernel/proc/proc_run.s').read_text()
load=src.split('proc_run_exec_ok:',1)[1].split('proc_run_claimed_bad:',1)[0]
assert 'pushj   17,mm_alloc_aligned' in load
assert 'jumpn   1,proc_run_mm_bad' in load
assert 'proc_run_mm_bad:' in load
rollback=src.split('proc_run_claimed_bad:',1)[1].split('proc_run_bad:',1)[0]
assert 'move    1,012' in rollback
assert 'pushj   17,proc_slot_discard' in rollback
assert 'proc_oom_select_v863' not in src
print('v982: failed RUN discards unpublished child; parent remains requester: PASS')
