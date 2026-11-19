#!/bin/sh
# Audit source-linked physical 48K PURE COMMIT entry, not inferred success.
# Mutate a private owner argument and descriptor pin to ensure refusal.
set -eu
: "${PURE_BRK_BUILD_V1615:?matching 48K PURE build required}"
: "${PURE_COMMIT_TRACE_V1620:?saved physical COMMIT entry trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-prefix-audit-v1620.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

audit()
{
    python3 "$here/audit-v1620.py" \
        "$PURE_BRK_BUILD_V1615/kcore.map" \
        "$PURE_BRK_BUILD_V1615/pure-mres-v1612.map" \
        "$PURE_BRK_BUILD_V1615/pure-mres-v1612.dxr" \
        "$1" "$PDP10_PREFIX/bin/dxrcheck"
}

audit "$PURE_COMMIT_TRACE_V1620"
python3 - "$PURE_COMMIT_TRACE_V1620" \
    "$work/owner-mutant.clean" "$work/pin-mutant.clean" <<'PY'
from pathlib import Path
import re
import sys
s = Path(sys.argv[1]).read_text()
start = s.index("Breakpoint, PC: 034614 ")
owner = re.search(r"(?m)^2:\s*000000000002\s*$", s[start:])
pin = re.search(r"(?m)^24307:\s*000014000002\s*$", s[start:])
assert owner and pin, "original physical COMMIT owner evidence drifted"
o = start + owner.start()
p = start + pin.start()
Path(sys.argv[2]).write_text(s[:o] + "2:\t000000000003" +
                             s[start + owner.end():])
Path(sys.argv[3]).write_text(s[:p] + "24307:\t000004000002" +
                             s[start + pin.end():])
PY

for name in owner pin; do
    if audit "$work/$name-mutant.clean" >"$work/$name.log" 2>&1; then
        echo "FAIL v1620: unsafe $name mutation accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1620 physical MM audit:' "$work/$name.log" || {
        cat "$work/$name.log" >&2
        exit 1
    }
    echo "PASS v1620: unsafe $name mutation rejected"
done
