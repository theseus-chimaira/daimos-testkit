#!/bin/sh
# Actual source-built PDP-6 DTC3 loss/recovery through original FULL MM.
set -eu
: "${V1845_BUILD:?source-built five-child 48K FULL guest required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1845_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-physical-v1845.XXXXXX")}
mkdir -p "$work"
if [ ! -s "$work/probe.clean" ]; then
    V1845_WORK="$work" sh "$here/probe-v1845.sh"
fi
base=$(python3 "$here/prepare-v1845.py" read "$V1845_BUILD" \
    "$work/probe.clean" | sed -n 's/^V1845_PURE_BASE=//p')
if [ -z "$base" ]; then
    echo 'FAIL v1845: original physical JRST did not locate PURE MRES' >&2
    exit 1
fi
python3 "$here/prepare-v1845.py" physical "$V1845_BUILD" \
    "$work" "$base" "$PDP10_PREFIX/bin/dxrcheck"
port=$((30000 + ($$ % 14000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/physical-headless.ini" \
    "$port" "$((port + 14000))"
set +e
(cd "$V1845_BUILD" && TERM=dumb timeout -k 3s \
    "${V1845_TIMEOUT:-900}" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$work/physical-headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -85 "$work/physical.clean" >&2
    echo "FAIL v1845: simulator status=$rc, physical source failure incomplete" >&2
    exit 1
fi
python3 "$here/verify-v1845.py" "$kit" "$V1845_BUILD" "$work"
python3 "$here/negative-v1845.py" "$here/verify-v1845.py" \
    "$kit" "$V1845_BUILD" "$work"
sha256sum "$V1845_BUILD/kcore.dxr" \
    "$V1845_BUILD/pure-mres-v1612.dxr" "$work/physical.clean"
echo "PASS v1845: actual original PDP-6 physical DTC3 source loss and return"
echo "v1845 physical evidence: $work"
echo 'NOT ACCEPTED: all PI6 interleavings, controller-loss policy or K05 closure'
