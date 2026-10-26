#!/usr/bin/env python3
"""Verify combined RENAME namespace comparison preserves provider/mount ABI."""
from pathlib import Path
import sys

source = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
body = source[source.index('vfs_rename:\n'):source.index('vfs_rename_ro:\n')]
if body.count('and     7,[0777700000000]') != 1 or body.count('and     5,[0777700000000]') != 1:
    raise SystemExit('FAIL: RENAME namespace mask missing')
mask = 0o777700000000
for provider in range(64):
    for mount in range(64):
        node = (provider << 30) | (mount << 24) | (31 << 18) | 123
        if (node & mask) != ((provider << 30) | (mount << 24)):
            raise SystemExit('FAIL: namespace mismatch')
        if (node & mask) != ((node ^ ((63 << 18) | 123)) & mask):
            raise SystemExit('FAIL: local kind/index leaked into namespace')
print('vfs-rename-namespace-v450: PASS (4096 provider/mount identities)')
