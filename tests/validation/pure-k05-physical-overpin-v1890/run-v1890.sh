#!/bin/sh
# Physical 48K original KCORE and PURE FULL with a real debugger MM pin2.
set -eu
: "${V1890_BUILD:?source-built v1855 48K PURE image required}"
: "${V1890_PROBE:?original runtime KCORE reclaim-JRST probe required}"
: "${V1890_PRIOR:?accepted v1848 original physical FULL evidence required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1890_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-physical-overpin-v1890.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1890.py" "$kit" "$V1890_BUILD" \
    "$V1890_PROBE" "$V1890_PRIOR" "$work" "$PDP10_PREFIX/bin/dxrcheck"
port=$((31000 + ($$ % 10000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 14000))"
set +e
(cd "$V1890_BUILD" && TERM=dumb timeout -k 3s "${V1890_TIMEOUT:-900}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -65 "$work/physical.clean" >&2
    echo "FAIL v1890: physical PDP-6 did not finish checkpoints ($rc)" >&2
    echo "evidence: $work" >&2
    exit 1
fi
python3 "$here/verify-v1890.py" "$kit" "$V1890_BUILD" "$work"
echo "v1890 physical evidence: $work"
