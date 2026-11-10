#!/bin/sh
# PDP-6 execution regression for optimized symbolic-address folding.
# The real FULL backing and mount-18 case must preserve swap_slots[SLOT].
# No production DAIMOS object is changed or linked by this test.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
DAIMOS_KCC_SYMBOL_TEST_FLAG_V1392=-DDAIMOS_TEST_KCC_SYMBOL_FOLD_V1392=1
export DAIMOS_KCC_SYMBOL_TEST_FLAG_V1392
sh "$testkit/tests/validation/exec-image-full-backing-v1390/run-v1390.sh"
asm="$TMPDIR/exec-image-full-backing-v1390-native/test-native-v1390.s"
test -s "$asm"
# Every swap_slots access in this fixture addresses the literal SLOT=1,
# never a runtime AC-indexed address. This catches the old bad form when
# other code changes recreate its register-allocation conditions.
if grep -Eq 'swap_slots\([0-9]+\)' "$asm"; then
    echo 'KCC emitted a runtime register index for fixed swap slot' >&2
    exit 1
fi
grep -Eq 'movem[[:space:]]+[0-9]+,swap_slots\+1' "$asm" || {
    echo 'KCC did not emit the expected constant-indexed store' >&2
    exit 1
}
printf '%s\n' 'PASS kcc-symbolic-address-fold-v1392'
