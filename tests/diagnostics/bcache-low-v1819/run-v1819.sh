#!/bin/sh
# Compare current production LOW cache placement with executable old HIGH.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${TMPDIR:=$HOME/tmp}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
validation=$(CDPATH= cd -- "$here/../../validation" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-bcache-low-v1819.XXXXXX")
if [ "${BCACHE_LOW_KEEP_V1819:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s" \
    "$work/mutant-high-v1819.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="ascii")
old = "        setzm   (17)                    ; arg 5: MM_ALLOC_LOW\n"
new = ("        movei   1,1                    ; unsafe MM_ALLOC_HIGH\n"
       "        movem   1,(17)                 ; arg 5: MM_ALLOC_HIGH\n")
assert source.count(old) == 1, "production LOW policy anchor changed"
assert ".equ    BCACHE_SLAB_WORDS,0201" in source
assert ".equ    BCACHE_MM_OWNER,6" in source
Path(sys.argv[2]).write_text(source.replace(old, new, 1),
                             encoding="ascii")
print("PASS v1819: extracted original cache source and HIGH mutant")
PY

DAIMOS_REPO="$DAIMOS_REPO" PDP10_PREFIX="$PDP10_PREFIX" \
    TMPDIR="$TMPDIR" sh "$validation/daimos-bcache-allocation-v1.sh"

if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 1000000 --timeout 20 \
    --workdir "$work/mutant-high" --name bcache-high-unsafe-v1819 \
    --expect __test_exit=0 \
    "$validation/daimos-test-crt0-v1.s" \
    "$validation/daimos-bcache-allocation-v1.s" \
    "$work/mutant-high-v1819.s" >"$work/mutant-high.log" 2>&1; then
    echo 'FAIL v1819: old HIGH cache policy was accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/mutant-high.log" || {
    tail -35 "$work/mutant-high.log" >&2
    echo 'FAIL v1819: HIGH mutant did not reach guest assertion' >&2
    exit 1
}
echo 'PASS v1819: cache MM_ALLOC_LOW; executable HIGH mutant rejected'
