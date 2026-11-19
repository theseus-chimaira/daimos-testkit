#!/bin/sh
# Rebuild a private 48K TSFS PURE pressure guest from the original v1614
# child/pipe/wait program, changing ONLY the deliberately oversized BRK
# target. The original test's guest assertions and ABI remain unchanged.
# This is experimental diagnostic evidence, not an unconditional PASS.
set -eu
: "${DAIMOS_REPO:?DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
source="$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c"
work=$(mktemp -d "$TMPDIR/pure-fit-source-v1621.XXXXXX")
trap 'echo "v1621 fitting source: $work"' EXIT HUP INT TERM
python3 - "$source" "$work/init-fit-v1621.c" <<'PY'
from pathlib import Path
import os
import sys
s = Path(sys.argv[1]).read_text()
old = "#define P14_BRK_TARGET       022000UL"
assert s.count(old) == 1, "original pressure source changed"
count = os.environ.get("PURE_FIT_CHILDREN_V1621", "4")
assert count in ("4", "6"), "only independently audited child counts allowed"
s = s.replace(old, "#define P14_BRK_TARGET       016000UL")
if count == "6":
    child = "#define P14_CHILDREN         4U"
    assert s.count(child) == 1
    s = s.replace(child, "#define P14_CHILDREN         6U", 1)
Path(sys.argv[2]).write_text(s)
PY
echo "v1621: original PIPE/WAIT pressure with 016000-word BRK and ${PURE_FIT_CHILDREN_V1621:-4} children"
export PURE_BRK_SOURCE_V1615="$work/init-fit-v1621.c"
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-370}
export KEEP_TEST=1
exec sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
