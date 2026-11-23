#!/bin/sh
# Physical original 48K PDP6: native MM rollback and child unlock.
set -eu
: "${V1902_BUILD:?original 48K source-built recovery image required}"
: "${V1902_PROBE:?original installed PURE JRST probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1902_COMMIT_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-reconcile-commit-v1902.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-physical-commit-v1902.py" "$kit" "$V1902_BUILD" \
    "$V1902_PROBE" "$work" "$PDP10_PREFIX/bin/dxrcheck" \
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump"
port=$((38600 + ($$ % 2000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1902_BUILD" && TERM=dumb timeout -k 3s "${V1902_TIMEOUT:-900}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/physical.clean" >&2
    echo "FAIL original 48K v1902 native target rollback ($rc): $work" >&2
    exit 1
fi
python3 "$here/verify-physical-commit-v1902.py" "$kit" "$V1902_BUILD" "$work"
echo "v1902 actual native target cleanup and child unlock: $work"
