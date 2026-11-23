#!/bin/sh
# Original 48K PDP6 physically completed mm_free but lost success reply.
set -eu
: "${V1893_BUILD:?source-built original v1855 48K guest required}"
: "${V1893_PROBE:?original installed PURE MRES JRST probe required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1893_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-source-free-reply-v1893.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1893.py" "$kit" "$V1893_BUILD" \
    "$V1893_PROBE" "$work" "$PDP10_PREFIX/bin/dxrcheck" \
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((30500 + ($$ % 10000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+13000))"
set +e
(cd "$V1893_BUILD" && TERM=dumb timeout -k 3s "${V1893_TIMEOUT:-850}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -70 "$work/physical.clean" >&2
    echo "FAIL v1893: no complete original 48K physical full/WAIT/HALT ($rc)" >&2
    echo "evidence: $work" >&2
    exit 1
fi
python3 "$here/verify-v1893.py" "$kit" "$V1893_BUILD" "$work"
echo "v1893 original physical lost successful free reply: $work"
