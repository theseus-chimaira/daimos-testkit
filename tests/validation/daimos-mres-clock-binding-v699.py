#!/usr/bin/env python3
"""Count wall-clock MRES consumers and verify conditional KINIT binding."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]) / 'system/kernel'
minit = (root/'modules/module_minit.c').read_text()
gateway = (root/'drivers/pclk_gateway.s').read_text()
syscall = (root/'proc/syscall_dispatch_pdp6.s').read_text()
consumers = []
for path in sorted(root.rglob('*.s')):
    if path == root/'drivers/pclk_gateway.s':
        continue
    source = path.read_text()
    count = len(re.findall(r'^\s*pushj\s+17,wall_time36\b', source, re.M))
    if count:
        consumers.append((str(path.relative_to(root)),count))
assert len(consumers) >= 3
assert '.word   native_sys_exec,,wall_time36' in syscall
assert 'jrst    wall_clock_set' in syscall
assert gateway.count('jrst wall_time36_unset') == 1
assert gateway.count('jrst wall_clock_set_unavailable') == 1
assert minit.count('storage_patch_jump(&wall_time36_provider_jump,') == 2
assert minit.count('storage_patch_jump(&wall_clock_set_provider_jump,') == 1
print('v699: wall-time direct callsites in resident/MRES assembly:')
for source,count in consumers:
    print('  %s: %d' % (source,count))
print('v699: syscall table has a packed reference, SETTIME has a direct JRST')
print('v699: PCLK and software clock mutually selected by KINIT; optional SETTIME retained')
print('v699: PASS')
