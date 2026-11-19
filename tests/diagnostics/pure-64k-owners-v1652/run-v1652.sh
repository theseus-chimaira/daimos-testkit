#!/bin/sh
# Genuine 64K source-built PDP-6 9-child PURE stress. A runnable
# simulator exit alone is not an accepted MM/peak-RAM profile.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-64k-source-v1652.XXXXXX")
trap 'echo "v1652 source-derived guest: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1652.py" \
    "$testkit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1652.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1652.c"
export PURE_TSFS_PRE_SIM_V1638="$testkit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=64
export PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-960}
export KEEP_TEST=1
sh "$testkit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
