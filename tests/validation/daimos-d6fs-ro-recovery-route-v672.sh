#!/bin/sh
# Verify production boot routes DIRTY selection only through explicit RO.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/boot/d6fs_boot.c"
python3 - "$src" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
marker = 'if ((flags & VFS_MOUNT_RDONLY) != 0U) {'
assert marker in s, 'RO recovery must be explicit'
branch = s.split(marker, 1)[1].split('selected = copy', 1)[0]
assert 'd6fs_super_select_recovery(a, b, total,' in branch
assert 'else if (d6fs_super_select(a, b, total,' in branch
assert 'flags, super_a, super_b, copy' in s
assert 'writable = (flags & VFS_MOUNT_RDONLY) == 0U' in s
assert 'if (writable)' in s
print('daimos-d6fs-ro-recovery-route-v672: source gate PASS')
PY
sh "$self/daimos-d6fs-recovery-select-v671.sh"
sh "$self/daimos-d6fs-super-recovery-v1.sh"
