#!/bin/sh
# Original 48K PDP6 native user TERM(3) after source MM-free real -5.
set -eu
: "${V1901_BUILD:?actual original 48K guest with TERM user source required}"
: "${V1901_PROBE:?installed physical PURE base observation required}"
: "${V1901_PRIOR:?accepted original v1895 pinned physical owners required}"
: "${V1901_V1900:?accepted updated PURE v1900 physical result required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1901_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-transition-term-v1901.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1901.py" "$kit" "$V1901_BUILD" \
    "$V1901_PROBE" "$V1901_PRIOR" "$V1901_V1900" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((36000 + ($$ % 3000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1901_BUILD" && TERM=dumb timeout -k 3s "${V1901_TIMEOUT:-900}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/physical.clean" >&2
    echo "FAIL v1901 original physical user TERM(3) ($rc): $work" >&2
    exit 1
fi
python3 "$here/verify-physical-v1901.py" "$kit" "$V1901_BUILD" "$work"
echo "v1901 original physical user TERM(3) evidence: $work"
