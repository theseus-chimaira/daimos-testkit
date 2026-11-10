#!/bin/sh
# Enforce the v1462 merge boundary: retain both codec sources but do not
# silently replace the accepted D6LZ36 production Stage-1 and KCORE path.
set -eu
: "${DAIMOS_REPO:?}"

root=$DAIMOS_REPO
for device in drm dsk dtc mtc ptr; do
    stage="$root/system/stand/pdp6/$device/stage1.s"
    grep -Fq '.include "../common/decompressor.inc"' "$stage" || {
        echo "FAIL v1462: $device Stage-1 no longer selects D6LZ36" >&2
        exit 1
    }
done

for file in \
    system/stand/pdp6/common/decompressor.inc \
    system/kernel/core/d6lz.h \
    system/kernel/core/d6lz_pdp6.s \
    tools/host/d6lz.c \
    tools/host/d6lz-codec.c \
    system/stand/pdp6/common/block_decompressor_v1458.inc \
    system/kernel/core/d6block_vfs_fixed_v1458.s \
    tools/host/d6block-codec-v1452.c; do
    test -f "$root/$file" || {
        echo "FAIL v1462: required retained source missing: $file" >&2
        exit 1
    }
done

grep -Fq 'cp core/d6lz_pdp6.s' "$root/system/kernel/Makefile"
grep -Fq '$(BUILD)/d6lz: d6lz.c' "$root/tools/host/Makefile"
grep -Fq 'd6lz-codec.c' "$root/tools/host/Makefile"

echo 'PASS v1462: all five Stage-1 and KCORE/host paths retain D6LZ36'
echo 'PASS v1462: versioned experimental block decoder and host codec retained'
