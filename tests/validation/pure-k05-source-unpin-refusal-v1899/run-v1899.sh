#!/bin/sh
# Physical original PDP6 mm_unpin(source) -4, target free, child retry.
set -eu
: "${V1899_BUILD:?original v1855 five-child source-built guest required}"
: "${V1899_PROBE:?installed original PURE MRES base probe required}"
: "${V1899_PRIOR:?accepted original v1897 physical MM trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1899_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-source-unpin-refusal-v1899.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1899.py" "$kit" "$V1899_BUILD" \
  "$V1899_PROBE" "$V1899_PRIOR" "$work" \
  "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((35700 + ($$ % 4500)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1899_BUILD" && TERM=dumb timeout -k 3s "${V1899_TIMEOUT:-850}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -80 "$work/physical.clean" >&2
  echo "FAIL original physical source unpin -4 ($rc): $work" >&2
  exit 1
fi
python3 "$here/verify-v1899.py" "$kit" "$V1899_BUILD" "$work"
echo "v1899 source unpin refusal physical evidence: $work"
