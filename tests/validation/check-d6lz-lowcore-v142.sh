#!/bin/sh
# KCORE must install the self-branching D6LZ36 decoder at address 000060.
# Every decoder-internal branch is assembled against that physical address;
# successful linking at another address silently breaks compressed EXEC.
set -eu
map=${1:?usage: check-d6lz-lowcore-v142.sh kcore.map}
entry=$(awk '$1 == "d6lz36_decode_core" { value = $2; n++ }
    END { if (n != 1) exit 1; print value }' "$map") || {
    echo 'FAIL: missing or duplicate fixed D6LZ36 decoder' >&2
    exit 1
}
case "$entry" in
    000060|00060|0060|060|60) ;;
    *) printf 'FAIL: D6LZ36 decoder linked at %s, expected 000060\n' "$entry" >&2
       exit 1 ;;
esac
echo 'PASS: D6LZ36 decoder linked at 000060'
