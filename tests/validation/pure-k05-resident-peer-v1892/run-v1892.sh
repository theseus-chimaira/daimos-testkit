#!/bin/sh
# Original 48K PDP-6 real pin2 quarantine and two resident parent HB ticks.
set -eu
: "${V1892_BUILD:?source-built original 48K with v1892 test-only INIT required}"
: "${V1892_PROBE:?source-matched installed PURE base probe required}"
: "${V1892_PRIOR:?accepted original v1848 physical FULL source required}"
: "${V1892_V1890:?accepted original v1890 physical transcript required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1892_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-resident-peer-v1892.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1892.py" "$kit" "$V1892_BUILD" \
    "$V1892_PROBE" "$V1892_PRIOR" "$V1892_V1890" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck"
port=$((30500 + ($$ % 9000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1892_BUILD" && TERM=dumb timeout -k 3s "${V1892_TIMEOUT:-860}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -66 "$work/physical.clean" >&2
    echo "FAIL v1892: physical PDP-6 did not finish actual two user heartbeats ($rc)" >&2
    echo "evidence: $work" >&2
    exit 1
fi
python3 "$here/verify-v1892.py" "$kit" "$V1892_BUILD" "$work"
echo "v1892 original source-built physical resident peer evidence: $work"
