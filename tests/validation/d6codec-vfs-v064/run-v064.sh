#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-vfs-v064-stack" \
 --name d6codec-vfs-v064-stack --expect __test_exit=0 \
 --examine __v064_first_changed \
 "$testkit/tests/validation/d6codec-vfs-v064/crt_stack_v064.s" \
 "$testkit/tests/validation/d6codec-vfs-v064/test_stack_v064.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v062.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"
