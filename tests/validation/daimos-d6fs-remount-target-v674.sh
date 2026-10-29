#!/bin/sh
# Check that the explicit internal remount target never blindly toggles.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/fs/vfs.s" "$DAIMOS_REPO/system/kernel/fs/vfs.h" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
h=Path(sys.argv[2]).read_text()
assert 'int vfs_remount_to(vnode_t node, unsigned int flags);' in h
f=s.split('vfs_remount_to:', 1)[1].split('vfs_shutdown_root:', 1)[0]
assert 'caile   2,1' in f
assert 'caie    3,6' in f
assert 'pushj   17,vfs_readonly' in f
assert 'camn    1,(17)' in f
assert 'pushj   17,vfs_remount' in f
assert 'sub     17,kconst_2_2' in f
assert 'vfs_remount:' in s
print('daimos-d6fs-remount-target-v674: source gate PASS')
PY
