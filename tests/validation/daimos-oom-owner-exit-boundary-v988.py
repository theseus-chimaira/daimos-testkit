#!/usr/bin/env python3
"""Audit current owner-exit failure boundary before OOM activation."""
import os
from pathlib import Path
root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel/proc'
asm = (root / 'proc_pdp6.s').read_text()
c = (root / 'proc.c').read_text()
finish = c.split('proc_exit_finish(int status)', 1)[1].split('\n}', 1)[0]
assert 'proc_current_slot = 0UL;' in finish
assert 'proc_finish_slot_owner_v932(slot,' in finish
assert 'return 1; /* slot 0 retries at the next clock tick */' in finish
assert 'return -1;' in finish
exitpath = asm.split('proc_exit_current:', 1)[1].split('proc_fatal_close_current_v879:', 1)[0]
assert 'pushj   17,proc_exit_finish' in exitpath
assert 'jumpl   1,proc_exit_release_failed' in exitpath
assert 'proc_exit_release_failed:' in exitpath
assert 'halt    1' in exitpath
finishpath = asm.split('proc_finish_slot:', 1)[1].split('proc_uarea_release:', 1)[0]
assert 'proc_finish_hup_fail_v876:' in finishpath
assert 'proc_finish_defer_uarea_v881:' in finishpath
assert 'proc_finish_mark_pending_v892' in finishpath
print('v988: deferred post-VM cleanup and pre-VM fatal HALT boundary verified: PASS')
print('v988: automatic OOM exit remains UNSAFE for pre-VM cleanup refusal')
