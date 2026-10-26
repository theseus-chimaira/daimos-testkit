#!/usr/bin/env python3
"""Verify TRUNCATE and WRITE share guards with distinct provider opcodes."""
from pathlib import Path
import re
import sys

s = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
t = s[s.index('vfs_truncate:\n'):s.index('.globl  vfs_chmod')]
w = s[s.index('vfs_write_words:\n'):s.index('.globl  vfs_sync')]
for name, body, opcode in (('truncate', t, '13'), ('write', w, '16')):
    if not re.search(r'movei\s+6,' + opcode, body):
        raise SystemExit('FAIL: ' + name + ' opcode')
if 'jrst    vfs_write_guard_v449' not in t:
    raise SystemExit('FAIL: TRUNCATE missing shared guard')
if not re.search(r'vfs_write_guard_v449:\s+pushj\s+17,vfs_readonly.*?'
                 r'pushj\s+17,proc_swap_backing_busy.*?'
                 r'pop\s+17,4.*?pop\s+17,3.*?pop\s+17,2.*?pop\s+17,1.*?'
                 r'jrst\s+fs_provider_reg_call', w, re.S):
    raise SystemExit('FAIL: shared readonly/swap provider frame')
print('vfs-write-guard-v449: PASS (TRUNCATE/WRITE shared readonly and swap guards)')
