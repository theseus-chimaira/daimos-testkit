#!/bin/sh
# Verify that staged D6FS picture assets are not deployed on the compact,
# single-member TSFS root.  This is a media packaging test, not a DSH size
# acceptance test (that separate gate is still awaiting optimization).
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-tsfs-root-no-pictures-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
manifest="$boot/tsfs-root.manifest"
image="$boot/media/tsfs-root0.dta"
trap 'rm -rf "$work"' EXIT HUP INT TERM

mkdir -p "$work/pictures"
# A valid, staged picture must be completely ignored for a tape root.
printf '%s\n' 000000000000 > "$work/pictures/TESTPIC.DPY"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" \
    ROOT=tape BOOT=dtc PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$build" \
    PICTURE_DIR="$work/pictures" DSH_IMAGE_LIMIT=037000 \
    "$image" > "$work/build.log" 2>&1 || {
        tail -45 "$work/build.log" >&2
        exit 1
    }

test -s "$image" && test -s "$manifest" || {
    echo "$tag: TSFS image or manifest missing" >&2
    exit 1
}
if grep -i '/PICTURES\|TESTPIC.DPY' "$manifest"; then
    echo "$tag: D6FS pictures leaked into TSFS root" >&2
    exit 1
fi
grep -q '^F /SYSTEM/INIT ' "$manifest" || {
    echo "$tag: INIT missing from TSFS root" >&2
    exit 1
}
grep -q '^F /SYSTEM/EXEC/DSH ' "$manifest" || {
    echo "$tag: DSH missing from TSFS root" >&2
    exit 1
}

echo "$tag: PASS (compact TSFS image has no /PICTURES; D6FS staging unchanged)"
