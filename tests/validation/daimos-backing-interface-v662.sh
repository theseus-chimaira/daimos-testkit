#!/bin/sh
# Verify BACKING capacity and I/O names are stable across DEVICE/VOLUME.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
import pathlib,re,sys
root=pathlib.Path(sys.argv[1])/'system/kernel'
bridge=(root/'fs/fs_mres.s').read_text()
monitor=(root/'fs/monitorfs_runtime.s').read_text()
swap=(root/'proc/proc_swap_boot.c').read_text()
header=(root/'storage/blockset.h').read_text()
assert re.search(r'^backstore_read:\s*\nblockset_direct_tail_read:',bridge,re.M)
assert re.search(r'^backstore_write:\s*\nblockset_direct_tail_write:',bridge,re.M)
assert re.search(r'^blockset_tail_blocks:\s*\nbacking_region_blocks:',bridge,re.M)
assert 'jrst    backing_region_io' in bridge
assert 'blocks = backing_region_blocks();' in swap
assert 'pushj   17,backing_region_blocks' in monitor
assert 'kword_t backing_region_blocks(void);' in header
assert 'blockset_runtime_service_call:\n        pushj   17,kret_neg1' in bridge
print('daimos-backing-interface-v662: PASS')
PY
