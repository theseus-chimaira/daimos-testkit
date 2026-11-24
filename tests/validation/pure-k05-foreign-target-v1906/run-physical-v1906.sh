#!/bin/sh
# Original 48K PDP-6 foreign-claimed FULL target must stay quarantined.
set -eu
: "${V1906_BUILD:?source-built v1906 48K guest required}"
: "${V1906_PROBE:?original v1906 PURE reclaim-JRST probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1906_PHYSICAL_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-foreign-target-v1906-physical.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1906.py" "$kit" "$V1906_BUILD" \
    "$V1906_PROBE" "$work" "$PDP10_PREFIX"
port=$((46500 + ($$ % 1800)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1906_BUILD" && TERM=dumb timeout -k 3s "${V1906_TIMEOUT:-900}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -85 "$work/physical.clean" >&2
    echo "FAIL v1906 original physical execution rc=$rc: $work" >&2
    exit 1
fi
python3 "$here/verify-physical-v1906.py" "$kit" "$V1906_BUILD" "$work"
echo "v1906 accepted original PDP6 foreign-owner/HALT evidence: $work"
