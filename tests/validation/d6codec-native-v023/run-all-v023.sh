#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in main literals boundary capacity; do
    case $kind in main) name=test_v023.s;; *) name=test_${kind}_v023.s;; esac
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 12 --workdir "$TMPDIR/d6codec-v023-$kind-run" \
        --name "v023-$kind" --expect __test_exit=0 \
        "$repo/tests/validation/daimos-test-crt0-v1.s" \
        "$repo/tests/validation/d6codec-native-v023/$name" \
        "$repo/tests/validation/d6codec-native-v023/encode_v023.s" \
        "$repo/tests/validation/d6codec-native-v023/decode_v023.s"
done
