#!/bin/sh
# Source-built current 48K PDP-6 secondary-backed FULL with five children.
set -eu
: "${DAIMOS_REPO:?current DAIMOS source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1845_SOURCE_DIR:-$(mktemp -d "$TMPDIR/daimos-k05-source-v1845.XXXXXX")}
mkdir -p "$work"
python3 "$kit/tests/diagnostics/pure-secondary-read-v1643/prepare-v1643.py" \
    "$kit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/original-six-v1643.c"
python3 "$here/prepare-v1845.py" source \
    "$work/original-six-v1643.c" "$work/init-five-v1845.c"
export PURE_BRK_SOURCE_V1615="$work/init-five-v1845.c"
export PURE_TSFS_PRE_SIM_V1638="$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48 PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${V1845_TIMEOUT:-860}
export KEEP_TEST=1
echo "v1845: five-child current-source physical 48K FULL baseline: $work"
exec sh "$kit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
