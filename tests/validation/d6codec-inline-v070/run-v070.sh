#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR/d6codec-inline-v070"
cat "$TESTKIT_REPO/tests/validation/d6codec-inline-v070/test-v070.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_fixed_v067.s" \
 > "$TMPDIR/d6codec-inline-v070/combined-v065.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 20 --workdir "$TMPDIR/d6codec-inline-v070/run" \
 --name d6codec-inline-v070 --expect __test_exit=0 \
 "$TESTKIT_REPO/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
 "$TMPDIR/d6codec-inline-v070/combined-v065.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_vfs_v070.s"
