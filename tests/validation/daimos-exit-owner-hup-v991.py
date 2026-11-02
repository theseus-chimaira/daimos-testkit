#!/usr/bin/env python3
"""Check that session-HUP preflight remains on the live EXIT owner stack."""
import os
from pathlib import Path
p = Path(os.environ['DAIMOS_REPO']) / 'system/kernel/proc/syscall_dispatch_pdp6.s'
s = p.read_text()
section = s.split('%L66:', 1)[1].split('%L67:', 1)[0]
assert section.index('pushj   17,file_close_all') < section.index('native_sys_exit_close_ok_v868:')
assert section.index('pushj   17,proc_session_teardown') < section.index('jrst    proc_exit_current')
assert 'move    2,-2(2)' in section
assert 'jumpn   1,native_sys_exit_hup_fail_v991' in section
assert 'native_sys_exit_hup_fail_v991:' in section
assert 'jrst    kret_neg1' in section
assert '.globl  proc_session_teardown' in s
print('v991: EXIT HUP preflight stays on owner stack; failure retains ownership: PASS')
