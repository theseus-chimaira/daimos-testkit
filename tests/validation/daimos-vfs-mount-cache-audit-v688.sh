#!/bin/sh
# Guard resident VFS mount ownership and two-slot cache footprint.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import re,sys
r=Path(sys.argv[1]); k=(r/'system/kernel/boot/kinit.c').read_text()
v=(r/'system/kernel/fs/vfs.s').read_text()
f=(r/'system/kernel/fs/fs_mres.s').read_text()
c=(r/'system/kernel/storage/bcache_pdp6.s').read_text()
slab=['reader','media','shape','extent','target','root']
dest=['d6fs_reader_slots_base','dtfs_media_base','tsfs_file_shape_base',
      'tsfs_extent_media_base','vfs_mount_target_base','vfs_mount_root_base']
for d,s in zip(dest,slab):
 assert re.search(r'\b'+d+r'\s*=\s*vfs_slab\.'+s+r'\s*;',k),(d,s)
 assert re.search(r'^'+d+r':\s*\n\s*\.word\s+(?:0|4)\b',v+'\n'+f,re.M),d
assert k.index('vfs_mount_target_base =') < k.index('vfs_mount_limit =')
assert re.search(r'^fs_block_workspace:\s*\n\s*\.block\s+0200\b',v,re.M)
assert 'BCACHE_SLAB_WORDS,0201' in c
assert 'fs_block_workspace' in c
assert re.search(r'^bcache_state:\s*\.block\s+1',c,re.M)
assert re.search(r'^bcache_workspace_tag:\s*\.block\s+1',c,re.M)
assert re.search(r'^vfs_mount_target_base:\s*\n\s*\.word\s+0',v,re.M)
assert re.search(r'^vfs_mount_root_base:\s*\n\s*\.word\s+0',v,re.M)
print('v688: six MM-slab mount arrays, publication order and 128-word shared workspace PASS')
print('v688: cache has 2 fixed control words and a dynamic 0201-word slab PASS')
PY
