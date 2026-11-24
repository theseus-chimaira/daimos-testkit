#!/bin/sh
# Original 48K PDP-6 native second FULL commit, typed child WAIT and HALT.
set -eu
: "${V1903_BUILD:?source-built original v1903 48K guest required}"
: "${V1903_PROBE:?source-built installed PURE base probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1903_PHYSICAL_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-full-commit-v1903-physical.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1903.py" "$kit" "$V1903_BUILD" \
    "$V1903_PROBE" "$work" "$PDP10_PREFIX"
port=$((42500 + ($$ % 2500)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1903_BUILD" && TERM=dumb timeout -k 3s "${V1903_TIMEOUT:-900}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/physical.clean" >&2
    echo "FAIL v1903 original 48K physical (rc=$rc): $work" >&2
    exit 1
fi
python3 "$here/verify-physical-v1903.py" "$kit" "$V1903_BUILD" "$work"
echo "v1903 original full commit/EXIT/WAIT/HALT evidence: $work"
