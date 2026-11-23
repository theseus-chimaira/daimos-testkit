#!/bin/sh
# Source-built original 48K PDP6 with updated terminal PURE MRES.
# Check original FULL persistent-free failure and autonomous parent HBs.
set -eu
: "${V1900_BUILD:?new original 48K source-linked boot with updated MRES required}"
: "${V1900_PROBE:?original installed 48K MRES JRST physical probe required}"
: "${V1900_PRIOR:?accepted original v1895 physical pinned MM owners required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1900_PHYSICAL_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-terminal-physical-v1900.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-v1900.py" "$kit" "$V1900_BUILD" \
    "$V1900_PROBE" "$V1900_PRIOR" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck" "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((35000 + ($$ % 4300)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(cd "$V1900_BUILD" && TERM=dumb timeout -k 3s "${V1900_TIMEOUT:-850}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -75 "$work/physical.clean" >&2
    echo "FAIL v1900 original physical PDP6 -5 + parent heartbeat ($rc)" >&2
    exit 1
fi
python3 "$here/verify-physical-v1900.py" "$kit" "$V1900_BUILD" "$work"
echo "v1900 actual 48K PDP6 source+PURE terminal binary: $work"
