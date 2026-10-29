#!/bin/sh
# Verify that explicitly requested RO recovery refuses missing tools.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
python3 - "$DAIMOS_REPO/system/kernel/boot/d6fs_boot.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert 'd6fs_boot_recovery_programs(void)' in s
for token in ("PDP10_SIX6('I', 'N', 'I', 'T', ' ', ' ')",
              "PDP10_SIX6('D', '6', 'F', 'S', 'C', 'K')",
              "PDP10_SIX6('M', 'O', 'U', 'N', 'T', ' ')"):
    assert token in s, token
assert 'st.size_words == 0UL' in s
assert 'vfs_read_words(node, (unsigned int)offset,' in s
assert 'if ((flags & VFS_MOUNT_RDONLY) != 0U &&' in s
assert 'd6fs_boot_recovery_programs() != 0)' in s
assert 'vfs_unmount(vfs_namespace_root)' in s
print('daimos-d6fs-recovery-tools-v673: source gate PASS')
PY
