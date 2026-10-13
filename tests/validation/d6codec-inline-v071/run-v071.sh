#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR/d6codec-inline-v071-test"
cat "$TESTKIT_REPO/tests/validation/d6codec-inline-v071/test-v071.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_fixed_v067.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_encode_v071.s" \
 > "$TMPDIR/d6codec-inline-v071-test/combined-v071.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-inline-v071-test/run" \
 --name d6codec-inline-v071 --expect __test_exit=0 \
 "$TESTKIT_REPO/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
 "$TMPDIR/d6codec-inline-v071-test/combined-v071.s"
