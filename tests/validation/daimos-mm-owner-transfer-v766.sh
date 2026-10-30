#!/bin/sh
# Native assembly and exact-pinning source contract for the exchange helper.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
out="$TMPDIR/daimos-mm-owner-transfer-v766-$$.dobj"
trap 'rm -f "$out"' EXIT
"$PDP10_PREFIX/bin/das" -C -F -O "$out" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
python3 - "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
p = s.split('mm_process_transfer_pinned:', 1)[1].split('mm_transfer_inval:', 1)[0]
for required in ('pushj   17,mm_find_base',
                 'caie    7,MM_TYPE_PROCESS',
                 'came    7,5',
                 'came    7,[MM_PIN_ONE]',
                 'hrr     4,6',
                 'movem   4,mm_extents+1(1)'):
    assert required in p, required
assert 'mm_delete' not in p and 'mm_extent_insert' not in p
print('v766: ownership/pin transfer contract PASS (assembly + structure)')
PY
