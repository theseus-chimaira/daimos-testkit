#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR/d6codec-fixed-v058"
cat "$TESTKIT_REPO/tests/validation/d6codec-fixed-v058/test-invalid-v058.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_fixed_v058.s" \
  > "$TMPDIR/d6codec-fixed-v058/combined-invalid-v058.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-fixed-v058/run-invalid" \
  --name d6codec-fixed-invalid-v058 --expect __test_exit=0 \
  "$TESTKIT_REPO/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$TMPDIR/d6codec-fixed-v058/combined-invalid-v058.s"
