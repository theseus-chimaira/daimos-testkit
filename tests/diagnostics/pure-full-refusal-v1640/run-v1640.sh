#!/bin/sh
# Physical PDP-6 REAL FULL allocation refusal, then plain-child relief.
# Do not turn this into an allocator stub or a KCORE fault injection.
set -eu
: "${DAIMOS_REPO:?source-matched DAIMOS checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-full-refusal-v1640.XXXXXX")
trap 'echo "v1640 original source and full guest log: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1640.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1640.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1640.c"
export PURE_TSFS_PRE_SIM_V1638="$testkit/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48
export PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-780}
export KEEP_TEST=1
exec sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
