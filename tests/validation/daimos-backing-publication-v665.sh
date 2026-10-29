#!/bin/sh
# Verify that failed BACKING writes cannot publish a swap/MEMFS extent.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1])/'system/kernel'
swap=(r/'proc/proc_swap_pdp6.s').read_text()
mem=(r/'fs/memfs_data_pdp6.s').read_text()
out=swap.split('proc_swap_out:',1)[1].split('proc_swap_in:',1)[0]
write=out.index('pushj   17,backstore_write')
assert out.index('jumpn   1,proc_swap_out_unpin',write) < out.index('movem   1,(12)',write), 'swap published before failure branch'
assert 'pushj   17,backstore_free' in out.split('proc_swap_out_record_fail:',1)[1], 'swap rollback does not free span'
evict=mem.split('memfs_evict_back_loop:',1)[1].split('memfs_evict_clear_start:',1)[0]
write=evict.index('pushj   17,backstore_write')
assert evict.index('jumpe   1,memfs_evict_back_store',write) < evict.index('movem   1,0700(2)',write), 'MEMFS published before write success'
assert 'pushj   17,backstore_free' in evict.split('jumpe   1,memfs_evict_back_store',1)[1].split('memfs_evict_back_store:',1)[0], 'MEMFS failed write does not free span'
print('daimos-backing-publication-v665: PASS')
PY
