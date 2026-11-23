#!/bin/sh
# Rebuild original 48K PDP-6 and one v1892 resident-parent guest, no sim.
set -eu
: "${DAIMOS_REPO:?production source-matched DAIMOS checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1892_SOURCE_DIR:-$(mktemp -d "$TMPDIR/daimos-k05-resident-peer-source-v1892.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-source-v1892.py" "$kit" "$work/init-parent-v1892.c"
export PURE_BRK_SOURCE_V1615="$work/init-parent-v1892.c"
export PURE_TSFS_PRE_SIM_V1638="$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48 PURE_ENABLE_V1631=1
export PURE_PREPARE_ONLY_V1892=1 KEEP_TEST=1
echo "v1892: source-built 48K physical resident-parent fixture: $work"
sh "$kit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
echo 'v1892: production KCORE/PURE and test-only resident heartbeat INIT ready'
