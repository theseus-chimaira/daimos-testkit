#!/bin/sh
# Prove that the v1432 bitmap pair fits an ordinary boot-installed MRES.
# This is a test-only package; it is not added to any KINIT MINIT table.
set -e
if [ -z "$PDP10_PREFIX" ]; then PDP10_PREFIX="$HOME/cross"; fi
if [ -z "$TMPDIR" ]; then TMPDIR="$HOME/tmp"; fi
if [ -z "$BOOT_BUILD" ]; then
    BOOT_BUILD="$HOME/git/DAIMOS/build/system/boot/pdp6"
fi
set -u
export PDP10_PREFIX TMPDIR
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
dest="$TMPDIR/d6codec-bitmap-v1434"
mkdir -p "$dest"
"$PDP10_PREFIX/bin/das" -F -C -O "$dest/bitmap-v1434.dobj" \
    "$here/bitmap-v1432.s"
"$PDP10_PREFIX/bin/dlink" -b 0 -A "$BOOT_BUILD/kcore.map" \
    -o "$dest/bitmap-v1434.dxr" \
    -M "$dest/bitmap-v1434.map" \
    -R "$dest/bitmap-v1434-package.dobj" \
    -N bitmap_ram_mres_package_v1434 \
    -X bitmap_encode_v1432 \
    -X bitmap_decode_v1432 \
    "$dest/bitmap-v1434.dobj" > "$dest/bitmap-v1434-link.txt"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$dest/bitmap-v1434.dobj" > "$dest/bitmap-v1434-object.txt"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$dest/bitmap-v1434-package.dobj" > "$dest/bitmap-v1434-package.txt"
grep -q '^sections: text=55 data=0 bss=0 ' \
    "$dest/bitmap-v1434-object.txt"
grep -q '^sections: text=0 data=63 bss=0 ' \
    "$dest/bitmap-v1434-package.txt"
grep -q '^bitmap_encode_v1432 ' "$dest/bitmap-v1434.map"
grep -q '^bitmap_decode_v1432 ' "$dest/bitmap-v1434.map"
echo 'PASS v1434: 55-word resident bitmap pair, 63-word MRES package'
