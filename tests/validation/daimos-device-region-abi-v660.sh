#!/bin/sh
# Check named DEVICE/VOLUME/REGION state retains legacy ABI aliases.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_swap_boot.c" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
p=open(sys.argv[2]).read()
for old,new in [('blockset_direct_map','device_region_map'),
                ('blockset_direct_blocks','volume_data_blocks'),
                ('blockset_direct_tail','backing_region_count')]:
    assert re.search(r'^'+old+r':\s*\n'+new+r':\s*\.block 1',s,re.M), (old,new)
assert re.search(r'^blockset_tail_blocks:\s*\nbacking_region_blocks:',s,re.M)
assert 'blocks = backing_region_blocks();' in p
assert 'blocks = blockset_tail_blocks();' not in p
assert 'skipn   volume_data_blocks' in s
assert 'move    6,backing_region_count' in s
print('daimos-device-region-abi-v660: PASS')
PY
