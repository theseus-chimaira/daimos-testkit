#!/bin/sh
# Isolated opt-in native simulator regression; currently known failing.
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=${HOME}/tmp}"
mkdir -p "$TMPDIR"
export PDP10_PREFIX TMPDIR
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 12 \
    --workdir "$TMPDIR/d6codec-native-v010-run" --name d6codec-v010 \
    --expect __test_exit=0 \
    "$repo/tests/validation/daimos-test-crt0-v1.s" \
    "$repo/tests/validation/d6codec-native-v010/test_v010.s" \
    "$repo/tests/validation/d6codec-native-v010/encoder_v009.s" \
    "$repo/tests/validation/d6codec-native-v010/decompressor_v009.inc"
