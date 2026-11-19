#!/bin/sh
# Physical 48K PURE pressure test for genuine PACKED restore under the
# corrected low clean-cache placement. No auxiliary disk or drum.
set -eu
: "${DAIMOS_REPO:?source-matched DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-cache-pressure-source-v1637.XXXXXX")
trap 'echo "v1637 generated original source: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1637.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1637.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1637.c"
export PURE_PHYS_KWORDS_V1626=48
export PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-570}
export KEEP_TEST=1
exec sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
