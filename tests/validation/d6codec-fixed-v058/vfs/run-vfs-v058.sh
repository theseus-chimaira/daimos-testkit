#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR/d6codec-fixed-v058-vfs"
cat "$TESTKIT_REPO/tests/validation/d6codec-fixed-v058/vfs/test-vfs-v058.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_fixed_v058.s" \
  > "$TMPDIR/d6codec-fixed-v058-vfs/combined-v058.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-fixed-v058-vfs/run" \
  --name d6codec-fixed-v058-vfs --expect __test_exit=0 \
  "$TESTKIT_REPO/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$TMPDIR/d6codec-fixed-v058-vfs/combined-v058.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v058.s"
