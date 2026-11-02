#!/usr/bin/env python3
"""Block unsafe partial conversion of private owner EXIT into OOM teardown."""
import os
from pathlib import Path
root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
proc = (root / 'proc/proc_pdp6.s').read_text()
syscall = (root / 'proc/syscall_dispatch_pdp6.s').read_text()
vm = (root / 'proc/vm_pdp6.s').read_text()
c = (root / 'proc/proc.c').read_text()
owner = proc.split('proc_finish_ids:',1)[1].split('proc_finish_uarea_retry_v881:',1)[0]
assert owner.index('pushj   17,proc_session_teardown') < owner.index('pushj   17,vm_space_destroy')
assert 'jumpn   1,proc_finish_hup_fail_v876' in owner
assert 'proc_finish_vm_done:' in owner
assert 'fs_provider_reg_call' in vm.split('vm_space_destroy:',1)[1].split('vm_space_load_file:',1)[0]
assert 'proc_swap_detach' in vm.split('vm_space_destroy:',1)[1].split('vm_space_load_file:',1)[0]
assert 'pushj   17,file_close_all' in syscall.split('%L66:',1)[1].split('%L67:',1)[0]
assert 'jrst    proc_exit_current' in syscall.split('%L66:',1)[1].split('%L67:',1)[0]
assert 'proc_current_slot = 0UL;' in c.split('proc_exit_finish(int status)',1)[1].split('}',1)[0]
assert 'proc_finish_service_post_vm_v894:' in proc
assert 'proc_oom_select_v863:' not in proc
print('v990: owner EXIT staging constraints and VM provider dependency PASS')
print('v990: do not activate automatic OOM kill before pre-VM owner transition test')
