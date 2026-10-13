#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for name in even odd_reject regression; do
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
      --start 1000 --timeout 12 --workdir "$TMPDIR/d6codec-native-v020-$name-run" \
      --name "d6codec-v020-$name" --expect __test_exit=0 \
      "$repo/tests/validation/daimos-test-crt0-v1.s" \
      "$repo/tests/validation/d6codec-native-v020/test_${name}_v020.s" \
      "$repo/tests/validation/d6codec-native-v020/decode_v020.s"
done
