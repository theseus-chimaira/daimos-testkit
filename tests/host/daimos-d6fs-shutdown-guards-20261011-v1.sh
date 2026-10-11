#!/bin/sh
# Verify the kernel's shutdown error and mount-state control-flow contract.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
python3 - "$DAIMOS_REPO" <<'PY'
import re
import sys
from pathlib import Path
repo = Path(sys.argv[1])
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
syscall = (repo / 'system/kernel/proc/syscall_dispatch_pdp6.s').read_text()
start = vfs.index('\nvfs_shutdown_root:')
end = vfs.index('\n; int vfs_unmount', start)
body = vfs[start:end]
# The guards precede the barrier; a read-only root must never be toggled.
ordered = ['move    1,vfs_namespace_root', 'jumpe   1,kret_zero',
           'caie    7,6', 'sojl    2,kret_neg1',
           'cail    2,4', 'tdne    4,vfs_mount_ro',
           'jrst    kret_zero', 'pushj   17,vfs_sync',
           'jumpn   1,kret_neg1', 'jrst    vfs_remount']
position = -1
for instruction in ordered:
    found = body.find(instruction, position + 1)
    if found < 0:
        raise SystemExit('missing/out-of-order shutdown guard: ' + instruction)
    position = found
# HALT must happen only after the shutdown call has returned success.
segment = syscall[syscall.index('%L136:'):syscall.index('%L137:')]
steps = ['pushj   17,file_check_root', 'jumpn   1,kret_neg1',
         'pushj   17,fs_memfs_shutdown', 'jumpn   1,kret_neg1',
         'pushj   17,vfs_shutdown_root', 'jumpn   1,kret_neg1', 'halt    .']
position = -1
for instruction in steps:
    found = segment.find(instruction, position + 1)
    if found < 0:
        raise SystemExit('unsafe HALT sequence: ' + instruction)
    position = found
print('D6FS shutdown assembly guard contract PASS')
PY
