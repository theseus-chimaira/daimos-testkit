#!/bin/sh
# Source-built 48K PDP-6 original clock PI6 while FULL MM pins held.
set -eu
: "${V1848_BUILD:?source-built physical v1845 48K image required}"
: "${V1848_PROBE:?observed source-linked v1845 JRST probe required}"
: "${DAIMOS_REPO:?source-matched original KCORE assembler required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1848_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-pi6-midfull-v1848.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1848.py" "$kit" "$V1848_BUILD" \
    "$V1848_PROBE" "$work" "$PDP10_PREFIX/bin/dxrcheck"
port=$((32500 + ($$ % 10000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 10000))"
set +e
(cd "$V1848_BUILD" && TERM=dumb timeout -k 3s \
    "${V1848_TIMEOUT:-900}" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -70 "$work/physical.clean" >&2
    echo "FAIL v1848: PDP-6 did not complete original FULL + PI6 (sim=$rc)" >&2
    echo "evidence: $work" >&2
    exit 1
fi
python3 "$here/verify-v1848.py" "$kit" "$V1848_BUILD" "$work"
python3 "$here/negative-v1848.py" "$kit" "$V1848_BUILD" "$work"
sha256sum "$V1848_BUILD/kcore.dxr" \
    "$V1848_BUILD/pure-mres-v1612.dxr" "$work/physical.clean"
echo 'PASS v1848: physical PDP-6 PI6 actually interrupted pinned PURE FULL'
echo "v1848 physical evidence: $work"
echo 'NOT ACCEPTED: arbitrary PI6 timing or permanent MM pin/allocator refusal'
