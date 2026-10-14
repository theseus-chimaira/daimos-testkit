#!/bin/sh
# Stage1's shared D6LZ core uses fixed-address branches to executive 000060.
# Its resident KCORE copy must be linked at precisely that address as well.
set -eu
map=${1:?usage: check-d6lz-fixed-placement-v142.sh KCORE.map}
base=$(awk '$1 == "d6lz36_decode_core" { print $2; n++ }
    END { if (n != 1) exit 1 }' "$map") || {
    echo 'FAIL: missing or duplicate D6LZ core symbol' >&2
    exit 1
}
case $base in
    000060) echo 'PASS: fixed D6LZ core linked at 000060' ;;
    *) echo "FAIL: D6LZ fixed branch base 000060 != linked core $base" >&2
       exit 1 ;;
esac
