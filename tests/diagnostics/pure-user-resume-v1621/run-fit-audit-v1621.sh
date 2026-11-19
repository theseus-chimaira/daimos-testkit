#!/bin/sh
# Source-backed negative control from a completed physical 48K no-AUX run.
set -eu
: "${PURE_FIT_SOURCE_V1621:?preserved four-child fitting source required}"
: "${PURE_FIT_TRACE_V1621:?preserved physical console required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-fit-audit-v1621.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-fit-v1621.py" \
    "$PURE_FIT_SOURCE_V1621" "$PURE_FIT_TRACE_V1621"
python3 - "$PURE_FIT_SOURCE_V1621" "$PURE_FIT_TRACE_V1621" \
    "$work/mutant.clean" <<'PY'
from pathlib import Path
import re
import sys
source = Path(sys.argv[1]).read_text()
s = Path(sys.argv[2]).read_text()
if re.search(r"#define P14_CHILDREN\s+6U", source):
    old = "aaaaa!c"
    new = "aaaaa!R"
else:
    old = "[A060450/042502]"
    new = "[A060451/042502]"
assert s.count(old) == 1, "physical fitting console drifted"
Path(sys.argv[3]).write_text(s.replace(old, new, 1))
PY
if python3 "$here/audit-fit-v1621.py" "$PURE_FIT_SOURCE_V1621" \
    "$work/mutant.clean" >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1621: false BRK-only geometry accepted' >&2
    exit 1
fi
grep -q '^FAIL v1621 fitting control audit:' "$work/mutant.log"
if grep -q '^#define P14_CHILDREN[[:space:]]*6U' \
    "$PURE_FIT_SOURCE_V1621"; then
    echo 'PASS v1621: unsafe sixth-child refusal mutation rejected'
else
    echo 'PASS v1621: unsafe physical growth mutation rejected'
fi
