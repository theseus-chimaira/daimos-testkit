#!/usr/bin/env python3
"""Verify readonly AC4 contract and RENAME's three-word save frame."""
from pathlib import Path
import re
import sys

source = (Path(sys.argv[1]) / 'system/kernel/fs/vfs.s').read_text()
rename = source.split('vfs_rename:\n', 1)[1].split('\n        .globl  vfs_name_valid', 1)[0]
readonly = source.split('vfs_readonly:\n', 1)[1].split('\n; int vfs_storage_release', 1)[0]
assert 'push    17,4' not in rename
assert 'pop     17,4' not in rename
assert 'sub     17,kconst_3_3' in rename
assert 'move    1,-1(17)' in rename
assert [int(n) for n in re.findall(r'^\s*push\s+17,([1234])\s*$',
    rename, re.M)] == [1, 2, 3]
assert not re.search(r'\b(?:move|movem|seto|setz|aos|sos|ldb|hlrz|hrrz|add|sub)\s+4\b', readonly), \
    'vfs_readonly newly clobbers AC4; restore RENAME save before proceeding'
print('daimos-vfs-rename-ac4-v472: PASS')
