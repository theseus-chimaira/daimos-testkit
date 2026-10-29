#!/usr/bin/env python3
"""Measure optional MRES call-site multiplicity and patch requirements."""
import re
import sys
from pathlib import Path


def main():
    root = Path(sys.argv[1]) / 'system/kernel'
    syscall = (root / 'proc/syscall_dispatch_pdp6.s').read_text()
    minit = (root / 'modules/module_minit.c').read_text()
    for symbol in ('sys_logstore_service_jump', 'sys_mtc_service_jump'):
        sites = len(re.findall(r'^\s*pushj\s+17,' + symbol + r'\b', syscall, re.M))
        assert sites > 1 and f'storage_patch_jump(&{symbol}' in minit
        assert re.search(r'^' + symbol + r':\s*\n\s*jrst\s+kret_neg1', syscall, re.M)
        print(f'{symbol}: {sites} callers, 1 KINIT-patched trampoline')
        print(f'  direct-patch variant: {sites} caller targets, {sites - 1} additional KINIT patch sites')
    print('v691: optional-gateway fan-out verified; direct patch would not remove call instructions')


if __name__ == '__main__':
    main()
