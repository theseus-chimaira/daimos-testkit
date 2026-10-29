#!/usr/bin/env python3
"""Verify that KINIT resolves clocks without any permanent clock trampoline."""
from pathlib import Path
import re
import sys

root=Path(sys.argv[1])/'system/kernel'
gw=(root/'drivers/pclk_gateway.s').read_text()
mini=(root/'modules/module_minit.c').read_text()
sc=(root/'proc/syscall_dispatch_pdp6.s').read_text()
assert 'wall_time36_provider_jump:' not in gw
assert 'wall_clock_set_provider_jump:' not in gw
assert re.search(r'wall_time36:\s*\nwall_time36_unset:\s*\n\s*setz\s+1,\s*\n\s*popj\s+17,',gw)
assert re.search(r'wall_clock_set:\s*\nwall_clock_set_unavailable:\s*\n\s*seto\s+1,\s*\n\s*popj\s+17,',gw)
assert 'minit_calendar_provider = minit_export(name, base, 0U);' in mini
assert mini.count('minit_calendar_provider = minit_export(name, base, 0U);')==2
assert mini.count('storage_patch_jump(&native_sys_clock_table_word,')==2
assert mini.count('storage_patch_jump(&native_sys_settime_call,')==1
assert 'minit_calendar_provider != 0U ? minit_calendar_provider :' in mini
assert 'minit_export(name, base, 1U)' in mini
assert 'native_sys_clock_table_word:' in sc
assert 'native_sys_settime_call:' in sc
print('v704: direct clock bindings, zero/-1 fallbacks, no gateway JRST: PASS')
