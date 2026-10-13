#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in main hidden literals boundary capacity; do
 case "$kind" in main) src=test_v029.s;; hidden) src=test_hidden_v029.s;; *) src=test_${kind}_v029.s;; esac
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 12 --workdir "$TMPDIR/d6codec-v029-$kind-run" \
 --name "d6codec-v029-$kind" --expect __test_exit=0 \
 "$repo/tests/validation/daimos-test-crt0-v1.s" \
 "$repo/tests/validation/d6codec-native-v029/$src" \
 "$repo/tests/validation/d6codec-native-v029/encode_v029.s" \
 "$repo/tests/validation/d6codec-native-v029/decode_v029.s"
done
