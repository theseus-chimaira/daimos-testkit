#!/bin/sh
# Source-linked 48K PDP6 native MM -5 and bounded slot-0 retry probe.
set -eu
: "${V1902_BUILD:?source-built 48K original KCORE/PURE required}"
: "${V1902_PROBE:?source-built 48K installed PURE JRST probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1902_PHYSICAL_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-reconcile-v1902-physical.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1902.py" "$kit" "$V1902_BUILD" \
    "$V1902_PROBE" "$work" "$PDP10_PREFIX/bin/dxrcheck" \
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((39000 + ($$ % 3000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1902_BUILD" && TERM=dumb timeout -k 3s "${V1902_TIMEOUT:-900}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -95 "$work/physical.clean" >&2
    echo "FAIL v1902 source-linked 48K physical ($rc): $work" >&2
    exit 1
fi
python3 "$here/verify-physical-v1902.py" "$kit" "$V1902_BUILD" "$work"
echo "v1902 original 48K physical MM recovery evidence: $work"
