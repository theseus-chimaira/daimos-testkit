#!/bin/sh
# Verify source-linked physical reverse RBN and optional PI5 completion.
# Mutation must be rejected from original captured guest bytes.
set -eu
: "${DAIMOS_REPO:?source checkout required}"
: "${PURE_DTC_BUILD_V1618:?matching 48K physical build required}"
: "${PURE_RBN_SYMBOL_MAP_V1619:?test-only map with identical TAPE image required}"
: "${PURE_RBN_TRACE_V1619:?physical RBN breakpoint trace required}"
mode=${PURE_RBN_AUDIT_MODE_V1619:-match}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/dtc-rbn-audit-v1619.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

audit()
{
    python3 "$here/audit-rbn-v1619.py" \
        "$PURE_DTC_BUILD_V1618/kcore.map" \
        "$PURE_RBN_SYMBOL_MAP_V1619" \
        "$PURE_DTC_BUILD_V1618/tape-mres.dxr" \
        "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$1" "$PDP10_PREFIX/bin/dxrcheck" "$mode"
}

audit "$PURE_RBN_TRACE_V1619"
python3 - "$PURE_RBN_TRACE_V1619" "$work/mutant.clean" <<'PY'
from pathlib import Path
import re
import sys
s = Path(sys.argv[1]).read_text()
start = s.index("Breakpoint, PC: 031046 ")
match = re.search(r"(?m)^31245:\s*000000000004\s*$", s[start:])
assert match is not None, "missing physical matched mark"
lo = start + match.start()
hi = start + match.end()
Path(sys.argv[2]).write_text(
    s[:lo] + "31245:\t000000000005" + s[hi:])
PY
if audit "$work/mutant.clean" >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1619: wrong physical PI3 RBN mark was accepted' >&2
    exit 1
fi
grep -q '^FAIL v1619 physical RBN audit:' "$work/mutant.log"
echo 'PASS v1619: physical RBN mismatch mutation rejected'

if [ "$mode" = transfer ]; then
    python3 - "$PURE_RBN_TRACE_V1619" "$work/transfer-mutant.clean" <<'PY'
from pathlib import Path
import re
import sys
s = Path(sys.argv[1]).read_text()
start = s.index("Breakpoint, PC: 030555 ")
m = re.search(r"(?m)^24174:\s*777777777777\s*$", s[start:])
assert m, "missing original DECtape read state -1"
lo = start + m.start()
hi = start + m.end()
Path(sys.argv[2]).write_text(
    s[:lo] + "24174:\t777777777776" + s[hi:])
PY
    if audit "$work/transfer-mutant.clean" \
        >"$work/transfer-mutant.log" 2>&1; then
        echo 'FAIL v1619: incorrect DCT completion type was accepted' >&2
        exit 1
    fi
    grep -q '^FAIL v1619 physical RBN audit:' \
        "$work/transfer-mutant.log"
    echo 'PASS v1619: unsafe DCT read-state mutation rejected'
fi
