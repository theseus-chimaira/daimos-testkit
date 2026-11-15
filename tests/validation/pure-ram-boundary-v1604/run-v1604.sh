#!/bin/sh
# Real PDP-6 KCC execution of the separated P1-E lifecycle/geometry checks.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:=$HOME/cross}"
: "${TMPDIR:=$HOME/tmp}"
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-boundary-v1604.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel"
if grep -Eq 'VM_PDP6_|PDP6_PURE_|EXEC_USER_ORIGIN' "$src/proc/proc_pure_lifecycle_v1604.h"; then
    echo 'FAIL: generic P1-E preflight depends on PDP-6 mapping' >&2
    exit 1
fi
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$src/proc" -I"$src/mm" -I"$src/core" \
    -I"$src/fs" -I"$src/storage" -I"$src/modules" \
    -I"$src/drivers" -I"$PDP10_PREFIX/include" \
    -S "$here/test-native-v1604.c" -o "$work/test-native-v1604.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-ram-boundary-v1604 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/test-native-v1604.s"
echo 'PASS P1-E v1604: portable lifecycle and PDP-6 retained range'
