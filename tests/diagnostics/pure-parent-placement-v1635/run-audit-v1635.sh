#!/bin/sh
# Source-matched original parent-placement obstruction and false witnesses.
set -eu
: "${PURE_PARENT_BUILD_V1635:?original PURE-on 48K guest required}"
: "${PURE_PARENT_TRACE_V1635:?first-VM physical breakpoint trace required}"
: "${PURE_PACKED_TRACE_V1635:?same guest's completed B/A/Z trace required}"
: "${DAIMOS_REPO:?original matching kernel source required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-parent-audit-v1635.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_PARENT_BUILD_V1635/kcore.map"
bcache="$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s"
python3 "$here/audit-v1635.py" "$map" "$PURE_PARENT_TRACE_V1635" \
    "$bcache" "$PURE_PACKED_TRACE_V1635"
python3 - "$PURE_PARENT_TRACE_V1635" "$work/owner-forgery" \
    "$work/span-forgery" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding='ascii')
start, end = 'V1635_BEFORE_FIRST_VM\n', 'V1635_END_FIRST_VM\n'
assert source.count(start) == source.count(end) == 1
before, rest = source.split(start, 1)
segment, after = rest.split(end, 1)
assert segment.count('24267:\t000003000006') == 1
assert segment.count('24266:\t000201137577') == 1
Path(sys.argv[2]).write_text(before + start + segment.replace(
    '24267:\t000003000006', '24267:\t000003000007', 1) + end + after,
    encoding='ascii')
Path(sys.argv[3]).write_text(before + start + segment.replace(
    '24266:\t000201137577', '24266:\t000200137577', 1) + end + after,
    encoding='ascii')
PY
for forged in owner-forgery span-forgery; do
    if python3 "$here/audit-v1635.py" "$map" "$work/$forged" \
        "$bcache" "$PURE_PACKED_TRACE_V1635" \
        >"$work/$forged.out" 2>&1; then
        echo "FAIL v1635: modified $forged physical witness accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1635 physical parent-placement audit:' \
        "$work/$forged.out"
done
echo 'PASS v1635: forged high-cache owner and extent length rejected'
