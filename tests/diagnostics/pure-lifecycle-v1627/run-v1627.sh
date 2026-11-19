#!/bin/sh
# Six-child 64K PURE lifecycle test: do not claim net RAM savings.
set -eu
: "${DAIMOS_REPO:?DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-lifecycle-source-v1627.XXXXXX")
trap 'echo "v1627 original source and generated guest: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1627.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1627.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1627.c"
export PURE_PHYS_KWORDS_V1626=64
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-490}
export KEEP_TEST=1
sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
