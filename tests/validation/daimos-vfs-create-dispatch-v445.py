#!/usr/bin/env python3
"""Verify CREATE and SYMLINK use one provider-call/result continuation."""
from pathlib import Path
import re
import sys

source = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
region = source[source.index('vfs_create_op:\n'):source.index('; int vfs_rename(')]
if region.count('pushj   17,fs_provider_reg_call') != 1:
    raise SystemExit('FAIL: expected one provider call in CREATE/SYMLINK')
if region.count('jrst    vfs_create_dispatch_v445') != 2:
    raise SystemExit('FAIL: CREATE and SYMLINK must share dispatch')
if not re.search(r'vfs_create_dispatch_v445:\s+pushj\s+17,fs_provider_reg_call\s+vfs_create_store_result:', region):
    raise SystemExit('FAIL: dispatch must fall through to result publication')
print('vfs-create-dispatch-v445: PASS (common provider and publication)')
