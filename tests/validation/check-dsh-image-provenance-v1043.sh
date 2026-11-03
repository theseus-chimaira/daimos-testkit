#!/bin/sh
# The provenance helper must accept identical binaries and reject any
# mismatch. This self-test does not assert the identity of a guest image.
set -eu
: "${TMPDIR:=$HOME/tmp}"
work="$TMPDIR/daimos-dsh-provenance-v1043-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
checker="$here/daimos-dsh-image-provenance-v1043.sh"
printf 'DSH-DXR-V1043\n' > "$work/reference.dxr"
cp "$work/reference.dxr" "$work/installed.dxr"
sh "$checker" "$work/reference.dxr" "$work/installed.dxr" \
    > "$work/identical.log"
grep -F 'PASS (byte-identical executable)' "$work/identical.log" >/dev/null
printf 'other' >> "$work/installed.dxr"
if sh "$checker" "$work/reference.dxr" "$work/installed.dxr" \
    > "$work/different.log" 2>&1; then
        echo 'FAIL: changed DSH image was accepted' >&2
        exit 1
fi
grep -F 'FAIL (different executable bytes)' "$work/different.log" >/dev/null
if sh "$checker" "$work/reference.dxr" "$work/missing.dxr" \
    > "$work/missing.log" 2>&1; then
        echo 'FAIL: missing DSH image was accepted' >&2
        exit 1
fi
echo 'PASS: DSH provenance detects exact match, change, and absent image'
