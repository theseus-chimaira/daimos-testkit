#!/bin/sh
# Build the original KCORE/PURE and test-only gated five-child parent.
set -eu
: "${DAIMOS_REPO:?original DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1903_SOURCE_DIR:-$(mktemp -d "$TMPDIR/daimos-k05-full-commit-v1903-source.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-source-v1903.py" "$kit" "$work/init-parent-v1903.c"
export PURE_BRK_SOURCE_V1615="$work/init-parent-v1903.c"
export PURE_TSFS_PRE_SIM_V1638="$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48 PURE_ENABLE_V1631=1
export PURE_PREPARE_ONLY_V1892=1 KEEP_TEST=1
echo "v1903 source-built original 48K PDP-6 pressure test: $work"
sh "$kit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
