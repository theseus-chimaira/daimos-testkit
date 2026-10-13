#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for name in hidden literals; do
  "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 12 --workdir "$TMPDIR/d6codec-v028-profile-$name" \
    --name "d6codec-v028-profile-$name" --expect __test_exit=0 \
    --examine d6v028_calls --examine d6v028_candidates \
    --examine d6v028_comparisons \
    "$root/tests/validation/daimos-test-crt0-v1.s" \
    "$root/tests/validation/d6codec-native-v028/test_${name}_v028.s" \
    "$root/tests/validation/d6codec-native-v028/encode_v028_instrumented.s" \
    "$root/tests/validation/d6codec-native-v028/decode_v028.s"
  grep -A6 '__P10RUN_EXAMINE__' "$TMPDIR/d6codec-v028-profile-$name/d6codec-v028-profile-$name.report.txt"
done
