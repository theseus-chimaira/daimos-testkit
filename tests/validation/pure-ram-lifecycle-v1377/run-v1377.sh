#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/pure-ram-lifecycle-v1377-native"
mkdir -p "$work"
include="-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/drivers -I$PDP10_PREFIX/include"
for name in proc_pure_ram_v1377 proc_storage_map_v28 \
    proc_packed_layout_v36 proc_packed_owner_v37; do
    # Deliberately split common include arguments here for KCC.
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -DDAIMOS_SWAPLESS_PURE_RAM_V1377=1 $include \
        -S "$DAIMOS_REPO/system/kernel/proc/$name.c" \
        -o "$work/$name.s"
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include \
    -S "$testkit/tests/validation/pure-ram-lifecycle-v1377/test-native-v1377.c" \
    -o "$work/test-native-v1377.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-ram-lifecycle-v1377 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1377.s" \
    "$work/proc_storage_map_v28.s" \
    "$work/proc_packed_layout_v36.s" \
    "$work/proc_packed_owner_v37.s" \
    "$work/test-native-v1377.s"
