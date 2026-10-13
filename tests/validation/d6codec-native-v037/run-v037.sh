#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in unique mixed period17 repeated; do
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v037-$kind" \
  --name "d6codec-v037-$kind" --expect __test_exit=0 \
  "$root/tests/validation/daimos-test-crt0-v1.s" \
  "$root/tests/validation/d6codec-native-v037/test_${kind}_v037.s" \
  "$root/tests/validation/d6codec-native-v037/encode_baseline_v037.s" \
  "$root/tests/validation/d6codec-native-v037/encode_cursor_v037.s"
done
