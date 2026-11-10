#!/bin/sh
# v1391 extends the legacy shared-code size gate with a trusted-capacity
# FULL callback. This remains a staged, unlinked component measurement.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
sh "$testkit/tests/validation/exec-image-size-v1390/run-v1390.sh"
work="$TMPDIR/exec-image-size-v1391"
mkdir -p "$work"
src="$DAIMOS_REPO/system/kernel"
include="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_RESTORE_V1391=1 $include \
    -S "$src/proc/proc_pure_ram_restore_v1391.c" \
    -o "$work/restore-v1391.s" >"$work/restore-kcc-v1391.log" 2>&1
"$PDP10_PREFIX/bin/das" -C -O "$work/restore-v1391.dobj" \
    "$work/restore-v1391.s"
sections=$("$PDP10_PREFIX/bin/pdp10-objdump" -h "$work/restore-v1391.dobj")
printf '%s\n' "$sections"
case "$sections" in
    *'data=0 bss=0'*) ;;
    *) echo 'v1391 restore allocated static DATA/BSS' >&2; exit 1 ;;
esac
restore=$(printf '%s\n' "$sections" |
    sed -n 's/^sections: text=\([0-9]*\).*/\1/p')
test "$restore" -le 359
printf '%s\n' 'PASS exec-image-size-v1391 (unlinked bounded restore budget)'
