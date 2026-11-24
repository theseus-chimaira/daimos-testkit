#!/bin/sh
# Original v1903 complete lifecycle, with a persistently pinned target.
set -eu
: "${V1904_BUILD:?source-built 48K v1903 parent and original kernel required}"
: "${V1904_PROBE:?original installed PURE reclaim base probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1904_PHYSICAL_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-target-pin-v1904-physical.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1904.py" "$kit" "$V1904_BUILD" \
    "$V1904_PROBE" "$work" "$PDP10_PREFIX"
port=$((43500 + ($$ % 2300)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1904_BUILD" && TERM=dumb timeout -k 3s "${V1904_TIMEOUT:-900}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/physical.clean" >&2
    echo "FAIL v1904 original 48K physical rc=$rc: $work" >&2
    exit 1
fi
python3 "$here/verify-physical-v1904.py" "$kit" "$V1904_BUILD" "$work"
echo "v1904 original target-pin/idle/commit/EXIT/WAIT physical: $work"
