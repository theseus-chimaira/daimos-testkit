#!/usr/bin/env python3
"""Check direct clock syscall table and SETTIME tail bindings."""
from pathlib import Path
import re
import sys
root=Path(sys.argv[1])/'system/kernel'
asm=(root/'proc/syscall_dispatch_pdp6.s').read_text()
minit=(root/'modules/module_minit.c').read_text()
assert re.search(r'native_sys_clock_table_word:\s*\n\s*\.word\s+native_sys_exec,,wall_time36',asm)
assert re.search(r'native_sys_settime_call:\s*\n\s*jrst\s+wall_clock_set',asm)
assert minit.count('storage_patch_jump(&native_sys_clock_table_word,') == 2
assert minit.count('storage_patch_jump(&native_sys_settime_call,') == 1
assert minit.count('storage_patch_jump(&wall_time36_provider_jump,') == 2
assert 'storage_patch_jump(&wall_clock_set_provider_jump,' in minit
print('v703: TIME36 table RH and SETTIME JRST direct KINIT bindings PASS')
