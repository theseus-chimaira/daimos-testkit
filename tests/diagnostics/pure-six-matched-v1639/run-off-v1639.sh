#!/bin/sh
# Source-identical six-child 48K PURE-disabled physical control.
# Compare with the accepted v1637 low-BCACHE PURE-enabled workload.
set -eu
: "${DAIMOS_REPO:?matching DAIMOS checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-six-matched-v1639.XXXXXX")
trap 'echo "v1639 original control sources/log: $work"' EXIT HUP INT TERM
python3 "$testkit/diagnostics/pure-cache-pressure-v1637/prepare-v1637.py" \
    "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1639.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1639.c"
export PURE_ENABLE_V1631=0
export PURE_PHYS_KWORDS_V1626=48
export PURE_LIFECYCLE_ONLY_V1627=1
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-690}
export KEEP_TEST=1
if ! sh "$testkit/diagnostics/pure-brk-pressure-v1614/run-v1614.sh" \
    >"$work/driver.log" 2>&1; then
    tail -75 "$work/driver.log" >&2
    echo 'FAIL v1639: PURE-OFF guest build/physical simulator failed' >&2
    exit 1
fi
cat "$work/driver.log"
case_dir=$(sed -n 's/^v1614: pressure guest evidence //p' \
    "$work/driver.log" | tail -1)
test -n "$case_dir" && test -f "$case_dir/console.clean"
grep -q 'HALT instruction' "$case_dir/console.clean"
grep -q 'aaaaaax\[B' "$case_dir/console.clean"
grep -q 'LwwwwwwZ' "$case_dir/console.clean"
if grep -q 'PURE[[:space:]]*LOADED' "$case_dir/console.clean"; then
    echo 'FAIL v1639: control silently installed PURE MRES' >&2
    exit 1
fi
if [ -n "${PURE_ON_BUILD_V1639:-}" ]; then
    cmp "$case_dir/user/init.dxr" \
        "$PURE_ON_BUILD_V1639/../user/init.dxr"
    cmp "$case_dir/build/kcore.map" \
        "$PURE_ON_BUILD_V1639/kcore.map"
    echo 'PASS v1639: PURE-ON/OFF user DXR and KCORE map byte-identical'
fi
echo "PASS v1639: 48K six-child source-matched PURE-OFF physical lifecycle"
echo "v1639 OFF_CASE=$case_dir"
