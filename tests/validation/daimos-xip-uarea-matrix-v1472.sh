#!/bin/sh
# Fault-injected full-profile XIP RUN/u-area lifetime at actual 128K,
# 192K, and 256K PDP-6 core sizes. Each run boots its own image and
# checks the KINIT-detected size, full XIP guest and injected counters.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sizes=${XIP_V1472_SIZES:-128 192 256}
for size in $sizes; do
    case "$size" in
        128) words=0400000 ;;
        192) words=0600000 ;;
        256) words=01000000 ;;
        *) echo "v1472: unsupported RAM profile $size" >&2; exit 2 ;;
    esac
    printf '\n=== v1472: full-profile XIP u-area fault, %sK core ===\n' "$size"
    XIP_V1472_BOOT_CORE_WORDS="$words" \
    XIP_V1472_SIMH_CPU_KWORDS="$size" \
    XIP_V1472_WORK="${XIP_V1472_WORK_PREFIX:-$TMPDIR/daimos-xip-uarea-v1472}-$size" \
    sh "$self/daimos-xip-uarea-retry-v1472.sh"
done
printf 'PASS v1472: injected XIP u-area rollback for %sK profile(s)\n' "$sizes"
