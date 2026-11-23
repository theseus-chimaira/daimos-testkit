#!/bin/sh
# Independently recheck the exact previously captured physical PI6 trace.
set -eu
: "${V1847_BUILD:?original source-built 48K PDP-6 guest required}"
: "${V1847_WORK:?original source-linked physical evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
for name in physical.log physical.clean expected-v1845.txt expected-pi6-v1847.txt; do
    test -s "$V1847_WORK/$name" || {
        echo "FAIL v1847: missing original physical evidence $name" >&2
        exit 1
    }
done
tr -d '\r' <"$V1847_WORK/physical.log" | \
    cmp - "$V1847_WORK/physical.clean" || {
    echo 'FAIL v1847: original simulator transcript no longer matches' >&2
    exit 1
}
python3 "$here/verify-v1847.py" "$kit" "$V1847_BUILD" "$V1847_WORK"
python3 "$here/negative-v1847.py" "$kit" "$V1847_BUILD" "$V1847_WORK"
sha256sum "$V1847_BUILD/kcore.dxr" \
    "$V1847_BUILD/pure-mres-v1612.dxr" "$V1847_WORK/physical.clean"
echo 'PASS v1847: original source-linked PI6 physical trace and negative controls'
