#!/bin/sh
# Recheck a previously completed real v1845 PDP-6 physical transcript.
set -eu
: "${V1845_BUILD:?original source-built v1845 physical guest required}"
: "${V1845_WORK:?original simulator evidence directory required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
for f in "$V1845_WORK/physical.log" \
         "$V1845_WORK/physical.clean" \
         "$V1845_WORK/probe.clean" \
         "$V1845_WORK/expected-v1845.txt"; do
    test -s "$f" || { echo "FAIL v1845: missing $f" >&2; exit 1; }
done
tr -d '\r' <"$V1845_WORK/physical.log" | \
    cmp - "$V1845_WORK/physical.clean" || {
    echo 'FAIL v1845: original physical simulator transcript mismatch' >&2
    exit 1
}
python3 "$here/prepare-v1845.py" read "$V1845_BUILD" \
    "$V1845_WORK/probe.clean"
python3 "$here/verify-v1845.py" "$kit" "$V1845_BUILD" "$V1845_WORK"
python3 "$here/negative-v1845.py" "$here/verify-v1845.py" \
    "$kit" "$V1845_BUILD" "$V1845_WORK"
sha256sum "$V1845_BUILD/kcore.dxr" \
    "$V1845_BUILD/pure-mres-v1612.dxr" "$V1845_WORK/physical.clean"
echo 'PASS v1845: original 48K DTC3 physical and forged-trace audit'
