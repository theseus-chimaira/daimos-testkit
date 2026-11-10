#!/bin/sh
# Native MRES package sizing and safe cross-domain p10fold analysis.
# Read-only against the linked KCORE map; installs no kernel modules.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the v1441 DAIMOS worktree}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
BOOT_BUILD=${BOOT_BUILD:-"$HOME/git/DAIMOS/build/system/boot/pdp6"}
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/d6codec-bitmap-v1451/pack-fold"
mkdir -p "$work"
binary="$PDP10_PREFIX/bin"

"$binary/das" -F -C -O "$work/bitmap-v1451.dobj" \
    "$here/bitmap-v1451.s"
"$binary/das" -F -C -O "$work/block-core-v1441.dobj" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_block_core_v1441.s"
"$binary/das" -F -C -O "$work/block-vfs-v1441.dobj" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1441.s"

"$binary/dlink" -b 0 -A "$BOOT_BUILD/kcore.map" \
    -o "$work/bitmap-v1451.dxr" \
    -M "$work/bitmap-v1451.map" \
    -R "$work/bitmap-v1451-package.dobj" \
    -N bitmap_ram_mres_package_v1451 \
    -X bitmap_encode_v1451 -X bitmap_decode_v1451 \
    "$work/bitmap-v1451.dobj" > "$work/mres-link-v1451.log"

"$binary/pdp10-dec-none-objdump" -h "$work/bitmap-v1451.dobj" \
    > "$work/bitmap-object-v1451.txt"
"$binary/pdp10-dec-none-objdump" -h \
    "$work/bitmap-v1451-package.dobj" \
    > "$work/bitmap-package-v1451.txt"
grep -q 'text=30 data=0 bss=0 ' "$work/bitmap-object-v1451.txt"
grep -q 'text=0 data=36 bss=0 ' "$work/bitmap-package-v1451.txt"
grep -q 'mres: initialized=30 bss=0 resident=30' \
    "$work/bitmap-package-v1451.txt"
grep -q '^bitmap_encode_v1451 ' "$work/bitmap-v1451.map"
grep -q '^bitmap_decode_v1451 ' "$work/bitmap-v1451.map"

"$binary/p10fold" -m 2 \
    -a "$work/block-core-v1441.dobj" \
    -a "$work/block-vfs-v1441.dobj" \
    "$work/bitmap-v1451.dobj" \
    > "$work/file-anchors-bitmap-donor-min2-v1451.txt"
"$binary/p10fold" -m 2 \
    -a "$work/bitmap-v1451.dobj" \
    "$work/block-core-v1441.dobj" \
    "$work/block-vfs-v1441.dobj" \
    > "$work/bitmap-anchor-file-donor-min2-v1451.txt"
"$binary/p10fold" -m 1 \
    -a "$work/block-core-v1441.dobj" \
    -a "$work/block-vfs-v1441.dobj" \
    "$work/bitmap-v1451.dobj" \
    > "$work/file-anchors-bitmap-donor-min1-v1451.txt"
"$binary/p10fold" -m 2 \
    "$work/block-core-v1441.dobj" \
    "$work/block-vfs-v1441.dobj" \
    "$work/bitmap-v1451.dobj" \
    > "$work/same-domain-min2-v1451.txt"

for report in "$work"/*-min2-v1451.txt; do
    case "$report" in
        *-anchor-*|*anchors-*)
            grep -q 'CROSS-DOMAIN TOTAL: 0 FOLDS; 0 WORDS' "$report"
            ;;
    esac
done
echo 'PASS 30 resident words, 36-word transient MRES package'
echo 'PASS cross-domain: no eligible runs of two or more words'
echo 'NOTE min1: a one-word shared POPJ was found, but requires'
echo '     cross-module symbol/relocation ownership to be useful'
