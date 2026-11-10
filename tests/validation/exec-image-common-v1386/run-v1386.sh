#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/exec-image-common-v1386-native"
mkdir -p "$work"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$PDP10_PREFIX/include" \
    -S "$testkit/tests/validation/exec-image-common-v1386/test-native-v1386.c" \
    -o "$work/test-native-v1386.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name exec-image-common-v1386 \
    --expect __test_exit=0 \
    --examine diag_meta0_v1386 --examine diag_meta1_v1386 \
    --examine diag_meta2_v1386 --examine diag_meta3_v1386 \
    --examine diag_rc_v1386 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$DAIMOS_REPO/system/kernel/proc/exec_image_common_v1386.s" \
    "$testkit/tests/validation/exec-image-common-v1386/backing-unused-v1386.s" \
    "$work/test-native-v1386.s"
