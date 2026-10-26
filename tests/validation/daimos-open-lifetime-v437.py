#!/usr/bin/env python3
"""Guard OPEN scratch-object lifetime before any frame-sharing rewrite."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
file = (root / 'system/kernel/fs/file_runtime.s').read_text()
syscall = (root / 'system/kernel/proc/syscall_dispatch_pdp6.s').read_text()
body = file[file.index('file_open:\n'):file.index('; Patched by TTY MINIT')]
checks = {
    'four saved nonvolatile registers': r'push\s+17,10.*push\s+17,11.*push\s+17,12.*push\s+17,13',
    '14-word local frame': r'add\s+17,\[016,,016\]',
    'create-only five-word leaf': r'file_parent_path.*?pushj\s+17,vfs_create',
    'stat buffer after creation': r'file_open_stat:.*?movei\s+2,-6\(17\).*?pushj\s+17,vfs_stat',
    'stat size remains live for append': r'file_open_append_offset:.*?move\s+1,-3\(17\)',
    'FIFO error clears descriptor': r'file_open_fifo_fail:.*?setzm\s+\(13\).*?setzm\s+1\(13\)',
}
for name, pattern in checks.items():
    if not re.search(pattern, body, re.S):
        raise SystemExit('FAIL: ' + name)
open_call = syscall[syscall.index('%L67:'):syscall.index('%L72:')]
if not re.search(r'pushj\s+17,native_sys_map_one.*pushj\s+17,file_open.*jrst\s+native_sys_mapped_return', open_call, re.S):
    raise SystemExit('FAIL: OPEN VM mapping lifetime')
print('daimos-open-lifetime-v437: PASS (create/stat/append/FIFO and VM mapping lifetime)')
