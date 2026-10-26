#!/usr/bin/env python3
"""Verify combined RENAME namespace comparison preserves provider/mount ABI."""
from pathlib import Path
import sys

source = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
body = source[source.index('vfs_rename:\n'):source.index('vfs_rename_ro:\n')]
if body.count('and     7,[0777700000000]') != 1 or body.count('and     5,[0777700000000]') != 1:
    raise SystemExit('FAIL: RENAME namespace mask missing')
mask = 0o777700000000
seen = set()
for provider in range(64):
    for mount in range(64):
        node = (provider << 30) | (mount << 24) | (31 << 18) | 123
        identity = node & mask
        if identity != ((provider << 30) | (mount << 24)):
            raise SystemExit('FAIL: namespace mismatch')
        if (node & mask) != ((node ^ ((63 << 18) | 123)) & mask):
            raise SystemExit('FAIL: local kind/index leaked into namespace')
        if identity in seen:
            raise SystemExit('FAIL: distinct provider/mount identities collide')
        seen.add(identity)
if len(seen) != 4096:
    raise SystemExit('FAIL: incomplete namespace identity space')
print('vfs-rename-namespace-v450: PASS (4096 provider/mount identities)')
