#!/bin/sh
# Physically distinguish failed RUN from a child not reaching SLEEP.
# Diagnostic experiment, not automatic RAW/WAIT/peak-RAM acceptance.
set -eu
: "${DAIMOS_REPO:?DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-pressure-cause-v1624.XXXXXX")
trap 'echo "v1624: source evidence $work"' EXIT HUP INT TERM
children=${PURE_CHILDREN_V1624:-5}
target=${PURE_BRK_TARGET_V1624:-017000}
python3 "$here/prepare-v1624.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1624.c" --children "$children" --target "$target"
export PURE_BRK_SOURCE_V1615="$work/init-v1624.c"
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-400}
export KEEP_TEST=1
sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh"
