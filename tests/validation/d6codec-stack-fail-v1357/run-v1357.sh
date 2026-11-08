#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-stack-fail-v1357"
mkdir -p "$work"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 30 --workdir "$work/run" \
  --name d6codec-stack-fail-v1357 --expect __test_exit=0 \
  --expect __v051_first_changed=016 \
  "$testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$testkit/tests/validation/d6codec-stack-fail-v1357/test_stack_fail_v1357.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_kcore_abi_v055.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_encode_v053.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
