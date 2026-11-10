#!/bin/sh
# Enforce v1464's single-format production block codec cutover.
set -eu
: "${DAIMOS_REPO:?}"

root=$DAIMOS_REPO
for device in drm dsk dtc mtc ptr; do
    stage="$root/system/stand/pdp6/$device/stage1.s"
    grep -Fq '.include "../common/block_decompressor_v1458.inc"' "$stage" || {
        echo "FAIL v1464: $device Stage-1 does not select the block core" >&2
        exit 1
    }
done

for file in \
    system/stand/pdp6/common/block_decompressor_v1458.inc \
    system/kernel/core/d6block_vfs_fixed_v1458.s \
    tools/host/d6block-codec-v1452.c \
    tools/host/d6block-v1452.c; do
    test -f "$root/$file" || {
        echo "FAIL v1464: required block codec source missing: $file" >&2
        exit 1
    }
done

for file in system/kernel/core/d6lz.h system/kernel/core/d6lz_pdp6.s \
    system/stand/pdp6/common/decompressor.inc tools/host/d6lz.c \
    tools/host/d6lz-codec.c tools/host/d6lz-codec.h \
    userland/d6lz/d6lz.c; do
    test ! -e "$root/$file" || {
        echo "FAIL v1464: obsolete D6LZ36 implementation remains: $file" >&2
        exit 1
    }
done
grep -Fq 'cp core/d6block_vfs_fixed_v1458.s' "$root/system/kernel/Makefile"
grep -Fq '$(BUILD)/d6block-v1452:' "$root/tools/host/Makefile"
grep -Fq 'd6block-codec-v1452.c' "$root/tools/host/Makefile"
grep -Fq 'D6BLOCK_HOST ?= $(BUILD)/d6block-v1464' \
    "$root/system/boot/pdp6/Makefile"
grep -Fq 'TSFSCHECK ?= $(BUILD)/tsfscheck-v1461' \
    "$root/system/boot/pdp6/Makefile"
grep -Fq 'd6codec_decode_vfs_v1458' "$root/system/kernel/proc/proc_swap_pdp6.s"
grep -Fq 'd6codec_decode_vfs_v1458' "$root/system/kernel/proc/exec_load.s"
grep -Fq 'd6codec_decode_buffer_v1458' "$root/system/kernel/fs/tsfs_runtime.s"
if rg -n 'd6lz36_decode|d6lz_fixed|\.d6lz\.dxr|D6LZ_HOST' \
    "$root/system/boot/pdp6/Makefile" "$root/system/kernel/Makefile" \
    "$root/system/kernel/proc/proc_swap_pdp6.s" \
    "$root/system/kernel/fs/tsfs_runtime.s"; then
    echo 'FAIL v1464: legacy decoder still selected' >&2
    exit 1
fi

echo 'PASS v1464: all five Stage-1 loaders, KCORE, EXEC, PURE and TSFS use block'
echo 'PASS v1464: obsolete D6LZ36 production sources and tools deleted'
