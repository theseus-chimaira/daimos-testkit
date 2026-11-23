#!/bin/sh
# Clean physical PDP-6 return from pin2 FULL to exact proc-table snapshot.
set -eu
: "${V1891_BUILD:?source-built v1855 48K image required}"
: "${V1891_PROBE:?source-linked physical MRES base probe required}"
: "${V1891_PRIOR:?accepted v1848 FULL owner evidence required}"
: "${V1891_V1890:?completed original v1890 physical trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1891_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-process-quarantine-v1891.XXXXXX")}
mkdir -p "$work"
python3 "$here/prepare-process-v1891.py" "$kit" "$V1891_BUILD" \
    "$V1891_PROBE" "$V1891_PRIOR" "$V1891_V1890" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck"
port=$((32000 + ($$ % 12000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+10000))"
set +e
(cd "$V1891_BUILD" && TERM=dumb timeout -k 3s "${V1891_TIMEOUT:-850}" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
    >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
    tail -65 "$work/physical.clean" >&2
    echo "FAIL v1891: no clean physical process-table checkpoint ($rc)" >&2
    echo "evidence: $work" >&2
    exit 1
fi
python3 "$here/verify-process-v1891.py" "$kit" "$V1891_BUILD" "$work"
sha256sum "$V1891_BUILD/kcore.dxr" "$V1891_BUILD/pure-mres-v1612.dxr" \
    "$work/physical.clean"
echo "v1891 exact physical process-table evidence: $work"
