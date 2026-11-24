#!/bin/sh
# Native PI6 clock entry with a permanently held foreign FULL owner.
set -eu
: "${V1909_BUILD:?source-built original v1907 48K guest required}"
: "${V1909_PROBE:?original PURE source-linked base probe required}"
: "${DAIMOS_REPO:?original source checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1909_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-held-pi6-v1909.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1909.py" "$kit" "$V1909_BUILD" \
  "$V1909_PROBE" "$work" "$PDP10_PREFIX"
port=$((52300+($$%1700)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1909_BUILD" && TERM=dumb timeout -k 3s "${V1909_TIMEOUT:-720}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -75 "$work/physical.clean" >&2
  echo "FAIL v1909 original physical rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1909.py" "$kit" "$V1909_BUILD" "$work"
echo "v1909 real native PI6/held-owner evidence: $work"
