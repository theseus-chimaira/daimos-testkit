#!/usr/bin/env python3
"""Check FILE RENAME parent lifetimes and four-argument provider handoff."""
from pathlib import Path
import sys

s = (Path(sys.argv[1]) / 'system/kernel/fs/file_runtime.s').read_text()
body = s[s.index('file_rename:\n'):s.index('; int file_chdir(')]
required = (
    'push    17,2',
    'add     17,kconst_14_14',
    'movei   2,-013(17)',
    'movei   3,-012(17)',
    'move    1,-014(17)',
    'movei   2,-5(17)',
    'movei   3,-4(17)',
    'move    1,-013(17)',
    'movei   2,-012(17)',
    'move    3,-5(17)',
    'movei   4,-4(17)',
    'pushj   17,vfs_rename',
    'sub     17,kconst_14_14',
    'pop     17,2',
)
if any(item not in body for item in required):
    raise SystemExit('FAIL: FILE RENAME frame or provider arguments changed')
if body.count('pushj   17,file_parent_path') != 2:
    raise SystemExit('FAIL: RENAME must resolve both parents')
if body.count('pushj   17,file_parent_write_access_v367') != 2:
    raise SystemExit('FAIL: RENAME must check both parent permissions')
print('file-rename-frame-v454: PASS (two parents, permissions, frame and handoff)')
