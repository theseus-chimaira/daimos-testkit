#!/bin/sh
# Verify LOG uses the existing bounded physical REGION service directly.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/storage/logstore_boot.c" \
    "$DAIMOS_REPO/system/kernel/storage/auxstore_boot.c" \
    "$DAIMOS_REPO/system/kernel/storage/auxstore.h" <<'PY'
import re,sys
log,aux,header=[open(p).read() for p in sys.argv[1:]]
for op in ('read','write'):
    call=r'auxstore_boot_region_'+op+r'\(AUXSTORE_REGION_LOGSTORE,\s*blockno, block\)'
    assert re.search(call,log), 'LOG must address its bounded REGION directly: '+op
    assert 'auxstore_boot_log_'+op not in aux+header+log
    assert 'blockset_boot_'+op in log, 'legacy root-backed LOG fallback lost'
assert 'blockno >= logstore_boot_count' in log
print('daimos-log-region-routing-v661: PASS')
PY
