#!/bin/sh
# Reject a forged source/trace outcome as well as accepting the real one.
set -eu
: "${PURE_SOURCE_V1624:?preserved compiled guest source required}"
: "${PURE_TRACE_V1624:?preserved physical simulator trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-v1624-audit.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-v1624.py" \
    "$PURE_SOURCE_V1624" "$PURE_TRACE_V1624"
python3 - "$PURE_SOURCE_V1624" "$PURE_TRACE_V1624" \
    "$work/mutant.log" <<'PY'
from pathlib import Path
import re
import sys
source = Path(sys.argv[1]).read_text(encoding="ascii")
trace = Path(sys.argv[2]).read_text(encoding="ascii")
count = re.search(r"(?m)^#define P14_CHILDREN\s+([56])U$", source)
assert count
if count.group(1) == "6":
    a = "aaaaa!r" if "aaaaa!r" in trace else "aaaaa!s"
    b = "aaaaa!c"
else:
    a = "[B063060/042502]"
    b = "[B063061/042502]"
assert trace.count(a) == 1
Path(sys.argv[3]).write_text(trace.replace(a, b, 1), encoding="ascii")
PY
if python3 "$here/audit-v1624.py" "$PURE_SOURCE_V1624" \
    "$work/mutant.log" >"$work/result.log" 2>&1; then
    echo 'FAIL v1624: forged physical witness accepted' >&2
    exit 1
fi
grep -q '^FAIL v1624 physical audit:' "$work/result.log"
echo 'PASS v1624: forged physical witness rejected'
