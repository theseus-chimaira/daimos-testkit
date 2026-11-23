#!/bin/sh
# Original native PDP6 mm_unpin refuses twice on a test-forced pin0.
set -eu
: "${V1898_BUILD:?original source-built 48K parent-HB guest required}"
: "${V1898_PROBE:?original installed PURE MRES base probe required}"
: "${V1898_PRIOR:?accepted original FULL owner physical evidence required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1898_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-target-unpin-refusal-v1898.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1898.py" "$kit" "$V1898_BUILD" \
  "$V1898_PROBE" "$V1898_PRIOR" "$work" \
  "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((35200 + ($$ % 5000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1898_BUILD" && TERM=dumb timeout -k 3s "${V1898_TIMEOUT:-850}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -75 "$work/physical.clean" >&2
  echo "FAIL v1898 actual native double unpin refusal ($rc): $work" >&2
  exit 1
fi
python3 "$here/verify-v1898.py" "$kit" "$V1898_BUILD" "$work"
echo "v1898 physical original double unpin refusal: $work"
