#!/bin/sh
# Bounded observation of a never-repaired foreign-claimed FULL owner.
set -eu
: "${V1908_BUILD:?source-built v1907 original 48K guest required}"
: "${V1908_PROBE:?source-linked installed PURE probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1908_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-permanent-owner-v1908.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1908.py" "$kit" "$V1908_BUILD" \
  "$V1908_PROBE" "$work" "$PDP10_PREFIX"
port=$((50900+($$%1700)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1908_BUILD" && TERM=dumb timeout -k 3s "${V1908_TIMEOUT:-700}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -65 "$work/physical.clean" >&2
  echo "FAIL v1908 original physical execution rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1908.py" "$kit" "$V1908_BUILD" "$work"
echo "v1908 observed nonterminal owner retention: $work"
