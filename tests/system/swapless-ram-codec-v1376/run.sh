#!/bin/sh
set -eu
: "${DAIMOS_REPO:?Set DAIMOS_REPO to the DAIMOS checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
    -I"$DAIMOS_REPO/system/kernel/core" \
    "$DAIMOS_REPO/system/kernel/core/kpack_ram_rle_v1376.c" \
    "$(dirname "$0")/test.c" \
    -o "$TMPDIR/swapless-ram-codec-v1376-test"
"$TMPDIR/swapless-ram-codec-v1376-test"
