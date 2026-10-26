#!/usr/bin/env python3
"""Check common three-argument mutation frame and provider opcodes."""
from pathlib import Path
import re
import sys

s = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
start = s.index('vfs_mutate2:\n')
end = s.index('; CHMOD is the compact', start)
block = s[start:end]
for pattern in (r'push\s+17,1\s+push\s+17,2\s+push\s+17,3',
                r'vfs_mutate3:\s+pushj\s+17,vfs_readonly',
                r'pop\s+17,3\s+pop\s+17,2\s+pop\s+17,1',
                r'vfs_mutate3_ro:\s+sub\s+17,kconst_3_3'):
    if not re.search(pattern, block):
        raise SystemExit('FAIL common mutation frame ' + pattern)
entry = s[s.index('vfs_setattr:\n'):s.index('.globl  vfs_read_words')]
if not re.search(r'movei\s+6,14.*push\s+17,1.*push\s+17,2.*push\s+17,3.*jrst\s+vfs_mutate3', entry, re.S):
    raise SystemExit('FAIL setattr operation/frame entry')
if not re.search(r'vfs_unlink:.*?movei\s+6,11.*?jrst\s+vfs_mutate2', s, re.S):
    raise SystemExit('FAIL unlink opcode')
if not re.search(r'vfs_chmod:.*?movei\s+6,14.*?vfs_mutate2:', s, re.S):
    raise SystemExit('FAIL chmod opcode')
print('vfs-mutation-frame-v443: PASS (UNLINK/CHMOD/SETATTR common frame)')
