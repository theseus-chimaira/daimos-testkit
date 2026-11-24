#!/bin/sh
# The original user sends TERM into the unreleased foreign FULL owner.
set -eu
: "${V1907_BUILD:?source-built v1907 original 48K guest required}"
: "${V1907_PROBE:?source-linked installed PURE probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1907_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-foreign-term-v1907.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1907.py" "$kit" "$V1907_BUILD" \
  "$V1907_PROBE" "$work" "$PDP10_PREFIX"
port=$((48300+($$%1800)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1907_BUILD" && TERM=dumb timeout -k 3s "${V1907_TIMEOUT:-850}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -55 "$work/physical.clean" >&2
  echo "FAIL v1907 original guest execution rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1907.py" "$kit" "$V1907_BUILD" "$work"
echo "v1907 original TERM/refused recovery/WAIT/HALT trace: $work"
