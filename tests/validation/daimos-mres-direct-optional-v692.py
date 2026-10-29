#!/usr/bin/env python3
"""Verify direct syscall-to-MRES patch sites retain absent-module failure."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]) / 'system/kernel'
asm = (root / 'proc/syscall_dispatch_pdp6.s').read_text()
minit = (root / 'modules/module_minit.c').read_text()
for provider, count in [('logstore', 5), ('mtc', 4)]:
    for i in range(count):
        symbol = 'sys_%s_call_%d' % (provider, i)
        assert len(re.findall(r'^' + symbol + r':\s*\n\s*pushj\s+17,kret_neg1\b', asm, re.M)) == 1, symbol
        assert ('&' + symbol) in minit, symbol
    assert 'storage_patch_optional_calls(' in minit
assert 'storage_patch_optional_calls(mtc_service, 0)' in minit
assert 'storage_patch_optional_calls(service, 1)' in minit
assert 'sys_logstore_service_jump:' not in asm
assert 'sys_mtc_service_jump:' not in asm
print('v692 direct optional MRES calls: 9 sites, absent fallbacks, KINIT patching PASS')
