#!/bin/sh
set -eu
: "${DAIMOS_REPO:?Set DAIMOS_REPO to the DAIMOS checkout}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/swapless-ram-codec-v1376-native"
mkdir -p "$work"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -S "$DAIMOS_REPO/system/kernel/core/kpack_ram_rle_v1376.c" \
    -o "$work/codec-v1376.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 20 \
    --workdir "$work/guest" --name swapless-codec-v1376 \
    --expect __test_exit=0 --examine stage_v1376 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/codec-v1376.s" \
    "$testkit/tests/validation/swapless-ram-codec-v1376/test-native-v1376.s"
