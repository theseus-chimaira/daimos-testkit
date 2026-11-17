#!/bin/sh
# Original PDP-6 source-built 48K RW DTFS executable backing guard guest.
set -eu
: "${DAIMOS_REPO:?current original DAIMOS source required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-backed-guards-v1644.XXXXXX")
trap 'echo "v1644 source-derived guest: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1644.py" \
    "$testkit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1644.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1644.c"
export PURE_TSFS_PRE_SIM_V1638="$testkit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48
export PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-1050}
export KEEP_TEST=1
exec sh "$testkit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
