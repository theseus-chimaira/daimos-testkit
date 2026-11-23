#!/bin/sh
# Real PDP-6 PCLK PI6 after a failed pinned two-extent FULL restore.
set -eu
: "${V1847_BUILD:?source-built v1845 48K physical FULL guest required}"
: "${V1847_PROBE:?source-linked original physical JRST probe required}"
: "${DAIMOS_REPO:?source-matched original KCORE assembler required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1847_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-pi6-v1847.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1847.py" "$kit" "$V1847_BUILD" \
    "$V1847_PROBE" "$work" "$PDP10_PREFIX/bin/dxrcheck"
port=$((32000 + ($$ % 11000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 11000))"
set +e
(cd "$V1847_BUILD" && TERM=dumb timeout -k 3s \
    "${V1847_TIMEOUT:-900}" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -75 "$work/physical.clean" >&2
    echo "FAIL v1847: original physical PI6 run incomplete (sim=$rc)" >&2
    echo "Evidence: $work" >&2
    exit 1
fi
python3 "$here/verify-v1847.py" "$kit" "$V1847_BUILD" "$work"
python3 "$here/negative-v1847.py" "$kit" "$V1847_BUILD" "$work"
sha256sum "$V1847_BUILD/kcore.dxr" \
    "$V1847_BUILD/pure-mres-v1612.dxr" "$work/physical.clean"
echo 'PASS v1847: original fixed-KCORE PI6 after failed FULL source restore'
echo "v1847 physical evidence: $work"
echo 'NOT ACCEPTED: actual PI6 interruption inside pinned FULL or persistent MM owner corruption'
