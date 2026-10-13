#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for pattern in unique repeated; do
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 15 \
  --workdir "$TMPDIR/d6codec-v030-$pattern-go" \
  --name "d6codec-v030-$pattern-go" --expect __test_exit=0 \
  "$root/tests/validation/daimos-test-crt0-v1.s" \
  "$root/tests/validation/d6codec-native-v030/test_${pattern}_v030.s" \
  "$root/tests/validation/d6codec-native-v030/encode_v030.s" \
  "$root/tests/validation/d6codec-native-v030/decode_v030.s"
done
