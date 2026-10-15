#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v061-resume" \
 --name d6codec-v061-resume --expect __test_exit=0 \
 "$testkit/tests/validation/daimos-test-crt0-v1.s" \
 "$testkit/tests/validation/d6codec-native-v061/test_group_resume_v061.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"

for name in truncated_group trailing_group; do
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v061-$name" \
  --name "d6codec-v061-$name" --expect __test_exit=0 \
  "$testkit/tests/validation/daimos-test-crt0-v1.s" \
  "$testkit/tests/validation/d6codec-native-v061/test_${name}_v061.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"
done
