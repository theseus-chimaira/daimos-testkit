#!/bin/sh
# Reject unsupported PDP-6 simulator core sizes before producing boot media.
set -eu
: "${DAIMOS_REPO:?}"
for size in 32 64 128 256; do
    make -s -n -C "$DAIMOS_REPO/system/boot/pdp6" \
        SIMH_CPU_KWORDS="$size" clean >/dev/null
done
if make -s -n -C "$DAIMOS_REPO/system/boot/pdp6" \
    SIMH_CPU_KWORDS=254 clean >/dev/null 2>&1; then
    echo 'FAIL: unsupported 254K simulator memory accepted' >&2
    exit 1
fi
echo 'PASS: simulator CPU core-size validation'
