#!/bin/sh
# Verify KCORE and minimum external MM descriptors fit below live KINIT.
set -eu
map=${1:?usage: check-mm-boot-gap-v134.sh kcore.map}
end=$(awk '$1 == "__kcore_low_end" { print $2; n++ }
    END { if (n != 1) exit 1 }' "$map") || exit 2
case "$end" in ''|*[!0-7]*) exit 2;; esac
if [ "$((0$end + 0100))" -gt "$((030000))" ]; then
    printf 'FAIL: end %s + 0100 descriptor words exceeds 030000 KINIT base\n' "$end" >&2
    exit 1
fi
printf 'PASS: KCORE end %s leaves room for 32 MM descriptors\n' "$end"
