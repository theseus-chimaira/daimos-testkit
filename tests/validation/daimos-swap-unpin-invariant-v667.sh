#!/bin/sh
# Rejected unpin must not resume a potentially pinned resident process.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" <<'PY'
import pathlib,re,sys
out=pathlib.Path(sys.argv[1]).read_text().split('proc_swap_out:',1)[1].split('proc_swap_in:',1)[0]
segment=out.split('pushj   17,backstore_write',1)[1].split('pushj   17,mm_free',1)[0]
assert re.search(r'pushj\s+17,mm_unpin\s*\n(?:[^\n]*\n)*?\s*jumpn\s+1,proc_swap_storage_invariant_v30',segment)
rollback=out.split('proc_swap_out_unpin:',1)[1].split('proc_swap_out_record_fail:',1)[0]
assert re.search(r'pushj\s+17,mm_unpin\s*\n(?:[^\n]*\n)*?\s*jumpn\s+1,proc_swap_storage_invariant_v30',rollback)
failure=out.split('proc_swap_out_record_fail:',1)[1].split('proc_swap_out_restore:',1)[0]
assert 'pushj   17,backstore_free' in failure
assert 'setzm   PROC_SWAP_BACKING_OFFSET(1)' in failure
assert 'andcmi  1,PROC_TRANSITION_RH' in failure
print('daimos-swap-unpin-invariant-v667: PASS')
PY
