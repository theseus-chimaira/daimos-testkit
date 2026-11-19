#!/bin/sh
# Force a sixth RUN refusal on 48K while preserving the original parent.
# Original five child statuses are checked before final Z; real MM
# ownership validation requires a separate source-matched replay.
set -eu
: "${DAIMOS_REPO:?DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-packed-source-v1629.XXXXXX")
trap 'echo "v1629 generated original-guest source: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1629.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1629.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1629.c"
export PURE_PHYS_KWORDS_V1626=48
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-520}
export KEEP_TEST=1
sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
