#!/bin/sh
set -eu
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(CDPATH= cd -- "$base/../../.." && pwd)
for w in 8 32 128; do
 cc -std=c99 -O2 -Wall -Wextra -I"$root/tests/host/d6codec-v006" \
    -DD6_TARGET_ENCODE=d6v025_encode_$w \
    -DD6_TARGET_DECODE=d6v025_decode_$w \
    "$base/compare_v025.c" "$base/codec_window_${w}_v025.c" \
    "$base/source_window_${w}_v025.c" \
    "$root/tests/host/d6codec-v006/codec_v006.c" \
    "$root/tests/host/d6codec-v006/source_v006.c" \
    -o "$TMPDIR/d6codec-v025-$w"
 awk 'NR>1 {print $1}' "$root/tests/host/d6codec-v006/results-v006.tsv" |
   xargs "$TMPDIR/d6codec-v025-$w" > "$TMPDIR/d6codec-v025-$w.tsv"
done
