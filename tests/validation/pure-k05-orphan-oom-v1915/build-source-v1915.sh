#!/bin/sh
# Source-built 48K original KCORE/PURE; only user APR BRK gate differs.
set -eu
: "${DAIMOS_REPO:?original DAIMOS source checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1915_SOURCE_DIR:-$(mktemp -d "$TMPDIR/daimos-k05-orphan-oom-v1915-source.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-source-v1915.py" "$kit" "$work/init-pressure-v1915.c"
export PURE_BRK_SOURCE_V1615="$work/init-pressure-v1915.c"
export PURE_TSFS_PRE_SIM_V1638="$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48 PURE_ENABLE_V1631=1
export PURE_PREPARE_ONLY_V1892=1 KEEP_TEST=1
echo "v1915 original PDP-6 48K KCORE/PURE with user-only OOM gate: $work"
sh "$kit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
