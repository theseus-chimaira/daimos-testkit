#!/bin/sh
# Regression of the actual PDP-6 swap-out late-failure control flow.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
body=s.split('proc_swap_out:',1)[1].split('proc_swap_in:',1)[0]
def check(cond,msg):
    if not cond: raise SystemExit('v666: '+msg)
write=body.index('pushj   17,backstore_write')
unpin=body.index('pushj   17,mm_unpin',write)
free=body.index('pushj   17,mm_free',unpin)
publish=body.index('pushj   17,proc_storage_publish_v30',free)
check(write<unpin<free<publish,'publication must follow successful MM release')
check(re.search(r'pushj\s+17,mm_unpin\s*\n(?:[^\n]*\n)*?\s*jumpn\s+1,proc_swap_storage_invariant_v30',body[write:free]),'failed unpin must halt on invalid MM ownership')
check(re.search(r'pushj\s+17,mm_free\s*\n\s*jumpn\s+1,proc_swap_out_record_fail',body[unpin:publish]),'failed MM free must rollback')
tail=body.split('proc_swap_out_record_fail:',1)[1].split('proc_swap_out_restore:',1)[0]
check('pushj   17,backstore_free' in tail,'failed MM release must free backing extent')
check('setzm   PROC_SWAP_BACKING_OFFSET(1)' in tail,'failed MM release must clear provisional backing record')
check('andcmi  1,PROC_TRANSITION_RH' in tail,'failed MM release must unlock resident process')
check('movem   1,(12)' not in body[write:free],'swap record cannot publish before MM free')
print('daimos-swap-late-rollback-v666: PASS (source control-flow)')
PY
