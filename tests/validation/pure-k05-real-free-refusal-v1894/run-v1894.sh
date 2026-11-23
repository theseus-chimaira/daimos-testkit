#!/bin/sh
# Actual original MM refuses source free due to temporary physical pin.
set -eu
: "${V1894_BUILD:?original source-built 48K v1855 build required}"
: "${V1894_PROBE:?actual original installed PURE MRES probe required}"
: "${V1894_PRIOR:?accepted original v1893 physical evidence required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1894_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-real-free-refusal-v1894.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1894.py" "$kit" "$V1894_BUILD" \
  "$V1894_PROBE" "$V1894_PRIOR" "$work" \
  "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((31300 + ($$ % 10000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+13000))"
set +e
(cd "$V1894_BUILD" && TERM=dumb timeout -k 3s "${V1894_TIMEOUT:-850}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/physical.clean" >&2
    echo "FAIL v1894 physical source free refusal ($rc): $work" >&2
    exit 1
fi
python3 "$here/verify-v1894.py" "$kit" "$V1894_BUILD" "$work"
echo "v1894 original physical source-free refusal: $work"
