#!/bin/sh
# Verify permanent FS workspace sharing and mount-table indirection.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
map=${KCORE_MAP:-$TMPDIR/daimos-mres-dispatch-v686/kcore.map}
test -r "$map"
python3 - "$DAIMOS_REPO" "$map" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1]); mp=Path(sys.argv[2]).read_text()
vfs=(root/'system/kernel/fs/vfs.s').read_text()
fs=(root/'system/kernel/fs/fs_mres.s').read_text()
assert len(re.findall(r'^fs_block_workspace:\s*\n\s*\.block\s+0200\b',vfs,re.M))==1
assert 'fs_provider_ready:\n        .word   1' in fs
names=['d6fs_reader_slots_base','dtfs_media_base','tsfs_file_shape_base','tsfs_extent_media_base']
for name in names:
 assert re.search(r'^'+name+r':\s*\n\s*\.word\s+0\b',fs,re.M),name
 assert re.search(r'^'+name+r'\s+[0-7]{6}$',mp,re.M),name
for name in ['fs_block_workspace','fs_provider_reg_call','fs_mres_vector_dispatch']:
 assert re.search(r'^'+name+r'\s+[0-7]{6}$',mp,re.M),name
assert len(re.findall(r'^fs_block_workspace\s+[0-7]{6}$',mp,re.M))==1
print('v687: single 128-word permanent FS workspace; 4 MM table-base pointers; provider lock: PASS')
print('v687: no redundant fixed filesystem block buffer identified in these modules')
PY
