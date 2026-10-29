#!/bin/sh
# Verify the native checker has RO-only, root-only logical-block inspection.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1])
s=(r/'system/kernel/proc/syscall_dispatch_pdp6.s').read_text()
h=(r/'system/kernel/proc/syscall.h').read_text()
u=(r/'userland/libc/syscall.s').read_text()
f=s.split('native_sys_d6fs_read_block:',1)[1].split('native_sys_d6fs_read_done:',1)[0]
assert '#define SYS_EXT_D6FS_READ_BLOCK    053U' in h
assert 'caile   5,033' in s
assert '.word   native_sys_brk,,native_sys_d6fs_read_block' in s
for item in ('file_check_root', 'vfs_namespace_root',
             'vfs_readonly', 'native_sys_map_one',
             'blockset_read_block'):
    assert item in f, item
assert 'blockset_write_block' not in f
assert 'dsys_d6fs_read_block:' in u
assert 'movei 1,053' in u
print('daimos-d6fs-rawread-v676: source gate PASS')
PY
