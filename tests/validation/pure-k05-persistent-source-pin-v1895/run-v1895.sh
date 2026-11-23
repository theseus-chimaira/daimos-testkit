#!/bin/sh
# Persistent source pin prevents FULL rollback/publication, parent continues.
set -eu
: "${V1895_BUILD:?source-built v1892 parent-HB original 48K image required}"
: "${V1895_PROBE:?actual installed MRES base probe required}"
: "${V1895_PRIOR:?actual v1894 real free-refusal source trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1895_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-persistent-source-pin-v1895.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1895.py" "$kit" "$V1895_BUILD" \
  "$V1895_PROBE" "$V1895_PRIOR" "$work" \
  "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((32500 + ($$ % 7000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1895_BUILD" && TERM=dumb timeout -k 3s "${V1895_TIMEOUT:-850}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -75 "$work/physical.clean" >&2
  echo "FAIL v1895 persistent source pin real PDP6 physical ($rc): $work" >&2
  exit 1
fi
python3 "$here/verify-v1895.py" "$kit" "$V1895_BUILD" "$work"
echo "v1895 persistent source pin real physical evidence: $work"
