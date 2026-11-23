#!/bin/sh
# Original target rollback physically succeeds, its return is lost.
set -eu
: "${V1897_BUILD:?original source-built 48K v1855 guest required}"
: "${V1897_PROBE:?original linked installed PURE MRES probe required}"
: "${V1897_PRIOR:?original v1894 physical source free-refusal required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1897_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-target-free-lost-reply-v1897.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-v1897.py" "$kit" "$V1897_BUILD" \
  "$V1897_PROBE" "$V1897_PRIOR" "$work" \
  "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((34100 + ($$ % 6000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1897_BUILD" && TERM=dumb timeout -k 3s "${V1897_TIMEOUT:-850}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -75 "$work/physical.clean" >&2
    echo "FAIL v1897 physical lost target-free reply ($rc): $work" >&2
    exit 1
fi
python3 "$here/verify-v1897.py" "$kit" "$V1897_BUILD" "$work"
echo "v1897 original physical target-free lost reply: $work"
