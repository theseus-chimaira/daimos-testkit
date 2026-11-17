#!/bin/sh
# Source-built 48K PDP-6 FULL v1391 under real compressed PURE backing.
set -eu
: "${DAIMOS_REPO:?matching DAIMOS source required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-full-source-v1638.XXXXXX")
trap 'echo "v1638 source fixture: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1638.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1638.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1638.c"
export PURE_TSFS_PRE_SIM_V1638="$here/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48
export PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-660}
export KEEP_TEST=1
exec sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
