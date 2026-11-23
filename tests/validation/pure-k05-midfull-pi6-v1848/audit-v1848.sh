#!/bin/sh
# Re-audit only an unmodified completed real PDP-6 mid-FULL PI6 trace.
set -eu
: "${V1848_BUILD:?original source-matched 48K PDP-6 build required}"
: "${V1848_WORK:?original physical PI6/restore transcript required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
for f in physical.log physical.clean expected-v1845.txt \
         expected-pi6-v1847.txt expected-pi6-v1848.txt; do
    test -s "$V1848_WORK/$f" || {
        echo "FAIL v1848: missing original witness $f" >&2
        exit 1
    }
done
tr -d '\r' <"$V1848_WORK/physical.log" | \
    cmp - "$V1848_WORK/physical.clean" || {
    echo 'FAIL v1848: physical original console transcript changed' >&2
    exit 1
}
python3 "$here/verify-v1848.py" "$kit" "$V1848_BUILD" "$V1848_WORK"
python3 "$here/negative-v1848.py" "$kit" "$V1848_BUILD" "$V1848_WORK"
sha256sum "$V1848_BUILD/kcore.dxr" \
    "$V1848_BUILD/pure-mres-v1612.dxr" "$V1848_WORK/physical.clean"
echo 'PASS v1848: original physical PI6 with both FULL pins alive'
