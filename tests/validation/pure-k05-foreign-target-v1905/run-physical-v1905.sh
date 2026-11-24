#!/bin/sh
# Reproduce an illegal foreign MM owner claim in original source-built KCORE.
set -eu
: "${V1905_BUILD:?source-built 48K v1903 guest required}"
: "${V1905_PROBE:?source-linked PURE installation probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1905_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-foreign-target-v1905.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1905.py" "$kit" "$V1905_BUILD" \
    "$V1905_PROBE" "$work" "$PDP10_PREFIX"
port=$((44100 + ($$ % 2000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1905_BUILD" && TERM=dumb timeout -k 3s "${V1905_TIMEOUT:-650}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -70 "$work/physical.clean" >&2
    echo "FAIL v1905 physical execution rc=$rc: $work" >&2
    exit 1
fi
python3 "$here/verify-physical-v1905.py" "$kit" "$V1905_BUILD" "$work"
