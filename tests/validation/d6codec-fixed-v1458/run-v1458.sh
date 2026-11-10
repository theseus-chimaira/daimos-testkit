#!/bin/sh
# Reproduce all fixed-low-core v1458 component acceptance tests.
# No production boot media or DAIMOS source is modified.
set -eu
DAIMOS_REPO=${DAIMOS_REPO:?set DAIMOS_REPO to the v1458 DAIMOS worktree}
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
BOOT_DXR_DIR=${BOOT_DXR_DIR:-"$HOME/git/DAIMOS/build/system/boot/pdp6"}
export TMPDIR PDP10_PREFIX
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/d6codec-fixed-v1458-acceptance"
mkdir -p "$work"

"$PDP10_PREFIX/bin/das" -F -C \
    -O "$work/fixed-v1458.dobj" \
    "$DAIMOS_REPO/system/stand/pdp6/common/block_decompressor_v1458.inc"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/fixed-v1458.dobj" | tee "$work/object-size-v1458.txt"
grep -q 'sections: text=53 data=0 bss=0 ' "$work/object-size-v1458.txt"
grep -q 'relocs=0' "$work/object-size-v1458.txt"

"$PDP10_PREFIX/bin/das" -F -C \
    -O "$work/vfs-v1458.dobj" \
    "$DAIMOS_REPO/system/kernel/core/d6block_vfs_fixed_v1458.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/vfs-v1458.dobj" | tee "$work/vfs-size-v1458.txt"
grep -q 'sections: text=58 data=0 bss=0 ' "$work/vfs-size-v1458.txt"

python3 -B "$base/fixed-native-v1458.py" \
    --daimos "$DAIMOS_REPO" --boot "$BOOT_DXR_DIR" \
    --work "$work/fixed" --prefix "$PDP10_PREFIX"
python3 -B "$base/vfs-native-v1458.py" \
    --daimos "$DAIMOS_REPO" --boot "$BOOT_DXR_DIR" \
    --work "$work/vfs" --prefix "$PDP10_PREFIX"
python3 -B "$base/stage1-assembly-v1458.py" \
    --daimos "$DAIMOS_REPO" --work "$work/stage1" \
    --prefix "$PDP10_PREFIX"
echo 'PASS all v1458 component acceptance and five Stage-1 assemblies'
