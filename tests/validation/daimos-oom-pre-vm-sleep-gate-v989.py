#!/usr/bin/env python3
"""Fail-closed OOM gate for sleeping pre-VM owner teardown."""
import os
from pathlib import Path
root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
proc = (root / 'proc/proc_pdp6.s').read_text()
exitc = (root / 'proc/proc.c').read_text()
mm = (root / 'mm/mm_pdp6.s').read_text()
finish = proc.split('proc_finish_ids:', 1)[1].split('proc_finish_vm_done:', 1)[0]
assert 'pushj   17,proc_session_teardown' in finish
assert 'jumpn   1,proc_finish_hup_fail_v876' in finish
assert 'pushj   17,vm_space_destroy' in finish
assert 'jrst    proc_finish_fail' in finish
service = proc.split('proc_finish_service_v881:', 1)[1].split('proc_slot_discard:', 1)[0]
assert 'proc_finish_service_post_vm_v894:' in service
assert 'proc_finish_service_check_v881:' in service
assert 'PROC_FINALIZE_MARK_LH' in service
assert 'pushj   17,proc_finish_slot' in service
assert 'proc_session_teardown' not in service
assert 'proc_current_slot = 0UL;' in exitc
assert 'return -1;' in exitc
assert 'proc_exit_release_failed:' in proc
assert 'halt    1' in proc.split('proc_exit_release_failed:', 1)[1].split('proc_fatal_close_current_v879:', 1)[0]
assert 'proc_oom_select_v863:' not in proc
assert 'pushj   17,proc_swap_reclaim' in mm
print('v989: pre-VM HUP/VM failure is NOT eligible for slot-zero retry: PASS')
print('v989: owner must remain live for possibly sleeping cleanup: OOM OFF')
