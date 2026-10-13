#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
exec "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 12 --workdir "$TMPDIR/d6codec-native-v015-run" \
 --name d6codec-v015 --expect __test_exit=0 \
 "$repo/tests/validation/daimos-test-crt0-v1.s" \
 "$repo/tests/validation/d6codec-native-v015/test_packed_v015.s" \
 "$repo/tests/validation/d6codec-native-v015/decode_v015.s"
