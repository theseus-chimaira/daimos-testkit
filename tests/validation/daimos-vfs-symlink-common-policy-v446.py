#!/usr/bin/env python3
"""Guard SYMLINK argument mapping into shared VFS create policy."""
from pathlib import Path
import re
import sys

s = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
body = s[s.index('vfs_symlink:\n'):s.index('; int vfs_rename(')]
for pattern in (r'jumpe\s+4,kret_neg1', r'push\s+17,4',
                r'move\s+4,3', r'move\s+3,2', r'move\s+2,1',
                r'movei\s+1,010', r'pushj\s+17,vfs_create_op',
                r'sub\s+17,kconst_1_1', r'popj\s+17,'):
    if not re.search(pattern, body):
        raise SystemExit('FAIL: missing SYMLINK mapping ' + pattern)
dispatch = s[s.index('vfs_create_dispatch_v445:\n'):s.index('vfs_create_store_result:\n')]
if not re.search(r'cain\s+6,010.*setz\s+5,.*pushj\s+17,fs_provider_reg_call', dispatch, re.S):
    raise SystemExit('FAIL: SYMLINK must zero unused provider argument e')
print('vfs-symlink-common-policy-v446: PASS (ABI mapping and provider e)')
