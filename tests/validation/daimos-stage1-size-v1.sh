#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
work="$TMPDIR/daimos-stage1-size-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
das="$PDP10_PREFIX/bin/das"
dxrcheck="$PDP10_PREFIX/bin/dxrcheck"
check_image()
{
        name=$1
        source=$2
        cap=$3
        out="$work/$name.dxr"
        "$das" -F -K -O "$out" "$source"
        report=`"$dxrcheck" "$out"`
        image=`printf '%s\n' "$report" | sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p'`
        test -n "$image"
        words=$((0$image))
        if test "$words" -gt "$cap"; then
                echo "$name: $words words exceeds cap $cap: $report" >&2
                exit 1
        fi
        printf '%s: %d/%d words\n' "$name" "$words" "$cap"
}
base="$DAIMOS_REPO/system/stand/pdp6"
# Baseline + 50 words, from the pre-decoder Stage1 images:
# DSK 302, DTC 56, MTC 54, PTR 77.
check_image dsk "$base/dsk/stage1.s" 352
check_image drm "$base/drm/stage1.s" 342
check_image dtc "$base/dtc/stage1.s" 106
check_image mtc "$base/mtc/stage1.s" 106
check_image ptr "$base/ptr/stage1.s" 139
cat >"$work/decoder.s" <<EOF_ASM
        .text
        .include "$base/common/decompressor.inc"
EOF_ASM
check_image decoder "$work/decoder.s" 62
