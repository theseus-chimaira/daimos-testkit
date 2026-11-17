#!/bin/sh
# Strict original physical 64K nine-owner MM oracle, with falsifications.
set -eu
: "${PURE_64K_BUILD_V1652:?original physical guest build required}"
: "${PURE_64K_TRACE_V1652:?original physical MM replay trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
build=$PURE_64K_BUILD_V1652
work=$(mktemp -d "$TMPDIR/daimos-pure-64k-audit-v1652.XXXXXX")
trap 'echo "v1652 original 64K audit: $work"' EXIT HUP INT TERM
python3 "$here/audit-mm-v1652.py" "$build" \
    "$build/../user/init-v1614.c" "$PURE_64K_TRACE_V1652" "$kit" \
    >"$work/real-owners-v1652.log"
cat "$work/real-owners-v1652.log"
python3 "$here/mutate-mm-v1652.py" "$build/kcore.map" \
    "$PURE_64K_TRACE_V1652" "$work/invalid"
for kind in packed-kind owner wait; do
    if python3 "$here/audit-mm-v1652.py" "$build" \
        "$build/../user/init-v1614.c" \
        "$work/invalid/false-$kind-v1652.trace" "$kit" \
        >"$work/rejected-$kind-v1652.log" 2>&1; then
        echo "FAIL v1652: false physical $kind witness accepted" >&2
        exit 1
    fi
    if ! grep -q '^FAIL v1652 physical 64K MM owner audit:' \
        "$work/rejected-$kind-v1652.log"; then
        cat "$work/rejected-$kind-v1652.log" >&2
        echo "FAIL v1652: false $kind witness not rejected by MM oracle" >&2
        exit 1
    fi
    echo "PASS v1652: fake physical $kind witness rejected"
done
echo "PASS v1652: original 64K physical nine-owner MM acceptance"
