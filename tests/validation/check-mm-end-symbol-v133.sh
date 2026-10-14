#!/bin/sh
# Verify the native KCORE linker locates external MM descriptors exactly
# at the first word after KCORE, without allocating backing inside BSS.
set -eu
map=${1:?usage: check-mm-end-symbol-v133.sh path/to/kcore.map}
end=$(awk '$1 == "__kcore_low_end" { print $2 }' "$map")
table=$(awk '$1 == "mm_extents" { print $2 }' "$map")
test -n "$end" && test -n "$table"
if test "$end" != "$table"; then
    printf 'FAIL: KCORE end=%s descriptor start=%s\n' "$end" "$table" >&2
    exit 1
fi
printf 'PASS: external MM descriptors begin at KCORE end %s\n' "$end"
