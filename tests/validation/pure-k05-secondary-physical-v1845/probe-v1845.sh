#!/bin/sh
# Original installed KCORE JRST determines the relocated PURE MRES base.
set -eu
: "${V1845_BUILD:?current-source 48K physical FULL guest required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1845_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-physical-v1845.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1845.py" probe "$V1845_BUILD" "$work"
port=$((30000 + ($$ % 15000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/probe.ini" "$work/probe-headless.ini" "$port" "$((port+15000))"
set +e
(cd "$V1845_BUILD" && TERM=dumb timeout -k 3s \
    "${V1845_TIMEOUT:-900}" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$work/probe-headless.ini") \
    >"$work/probe.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/probe.log" >"$work/probe.clean"
if [ "$rc" -ne 0 ]; then
    tail -65 "$work/probe.clean" >&2
    exit 1
fi
python3 "$here/prepare-v1845.py" read "$V1845_BUILD" \
    "$work/probe.clean"
echo "v1845 original physical MRES probe evidence: $work"
