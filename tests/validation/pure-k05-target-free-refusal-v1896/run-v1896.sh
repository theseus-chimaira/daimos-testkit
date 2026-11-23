#!/bin/sh
# Actual original PDP6 two real MM -5 calls, persistent target rollback pin.
set -eu
: "${V1896_BUILD:?source-built 48K resident-parent original image required}"
: "${V1896_PROBE:?actual installed MRES base probe required}"
: "${V1896_PRIOR:?original v1894 physically refused source free evidence required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1896_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-target-free-refusal-v1896.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1896.py" "$kit" "$V1896_BUILD" \
  "$V1896_PROBE" "$V1896_PRIOR" "$work" \
  "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((33400 + ($$ % 6000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1896_BUILD" && TERM=dumb timeout -k 3s "${V1896_TIMEOUT:-850}" \
   stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
   >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -85 "$work/physical.clean" >&2
    echo "FAIL v1896 real original PDP6 target cleanup refusal ($rc): $work" >&2
    exit 1
fi
python3 "$here/verify-v1896.py" "$kit" "$V1896_BUILD" "$work"
echo "v1896 original physical target free refusal: $work"
