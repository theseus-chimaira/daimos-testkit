#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for testname in v021 boundary capacity; do
    case "$testname" in
        v021) sourcefile=test_v021.s ;;
        boundary) sourcefile=test_boundary_v021.s ;;
        capacity) sourcefile=test_capacity_v021.s ;;
    esac
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
      --exec-mode go --start 1000 --timeout 12 \
      --workdir "$TMPDIR/d6codec-native-v021-$testname-run" \
      --name "d6codec-v021-$testname" --expect __test_exit=0 \
      "$repo/tests/validation/daimos-test-crt0-v1.s" \
      "$repo/tests/validation/d6codec-native-v021/$sourcefile" \
      "$repo/tests/validation/d6codec-native-v021/encode_v021.s" \
      "$repo/tests/validation/d6codec-native-v021/decode_v021.s"
done
