#!/bin/sh
# Recovery bootstrap checks whole files with existing transient workspace.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/boot/d6fs_boot.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
f=s.split('d6fs_boot_recovery_file(',1)[1].split('static int\nd6fs_boot_recovery_programs',1)[0]
assert 'scratch = d6fs_boot_block_buffer();' in f
assert 'while (offset < st.size_words)' in f
assert 'if (count > D6FS_BLOCK_WORDS)' in f
assert 'count = D6FS_BLOCK_WORDS;' in f
assert 'vfs_read_words(node, (unsigned int)offset,' in f
assert 'offset += (kword_t)count;' in f
assert 'st.size_words > 0777777UL' in f
assert 'kword_t first;' not in f
print('daimos-d6fs-recovery-fullread-v675: source gate PASS')
PY
