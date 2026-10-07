#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

tag=daimos-img2dpic-v1
work=$TMPDIR/$tag-$$
tool=$DAIMOS_REPO/build/tools/host/img2dpic
trap 'rm -rf "$work"' 0 1 2 3 15
mkdir -p "$work"

fail()
{
        echo "$tag: $1" >&2
        exit 1
}

command -v magick >/dev/null 2>&1 ||
        fail 'ImageMagick magick command is required by this regression'
test -x "$tool" || fail "converter is not built: $tool"

magick -size 2048x2048 xc:black "$work/black.png"
magick -size 2048x2048 xc:white "$work/white.png"
magick -size 2048x2048 xc:black -fill white \
        -draw 'rectangle 0,0 2047,1023' "$work/top.png"
magick -size 2048x2048 xc:black -fill white \
        -draw 'rectangle 200,100 260,1900 rectangle 500,300 560,1700 rectangle 900,50 980,1950 rectangle 1300,400 1360,1800 rectangle 1700,150 1780,1850' \
        "$work/vertical.png"
magick -size 2048x2048 xc:black -fill none -stroke white -strokewidth 2 \
        -draw 'circle 1024,1024 1024,250 line 200,300 1800,1700 line 1800,250 300,1800' \
        "$work/curve.png"
magick -size 2048x2048 xc:none "$work/alpha.png"

"$tool" "$work/black.png" "$work/black.dpic" 2>"$work/black.log"
"$tool" "$work/white.png" "$work/white.dpic" 2>"$work/white.log"
"$tool" "$work/top.png" "$work/top.dpic" 2>"$work/top.log"
"$tool" "$work/vertical.png" "$work/vertical.dpic" 2>"$work/vertical.log"
"$tool" "$work/curve.png" "$work/curve.dpic" 2>"$work/curve.log"

grep -q 'lit pixels=0, runs=0' "$work/black.log" ||
        fail 'black input unexpectedly emits lit vectors'
test "`wc -c < "$work/black.dpic"`" -eq 8 ||
        fail 'black frame is not the one-word dark display program'

grep -q 'lit pixels=1048576, runs=1024' "$work/white.log" ||
        fail 'white input polarity is not fully intensified'
grep -q 'halfwords=10240, words=5120' "$work/white.log" ||
        fail 'white input vector topology changed'

# Top raster rows must become high Type-340 Y coordinates.  The first word
# contains the parameter halfword followed by a non-intensified +127 Y move.
first_word=`od -An -tu8 -N8 "$work/top.dpic" | tr -d '[:space:]'`
test "$first_word" = 8593899264 ||
        fail 'raster Y axis is not reflected into Type-340 coordinates'

# A raster containing tall vertical strokes must be emitted column-wise.  This
# is a lossless scan-direction optimization: the same lit pixels are covered,
# but the Type-340 program is much shorter than horizontal scanline slicing.
grep -q 'scan=vertical' "$work/vertical.log" ||
        fail 'vertical-run scan optimization was not selected'
test "`wc -c < "$work/vertical.dpic"`" -lt 8000 ||
        fail 'vertical-run scan optimization did not compact the display list'

# Thin curves and diagonals are cheaper as Type-340 incremental paths.  The
# source geometry is unchanged: each step advances to one already-lit
# neighboring pixel, with four one-pixel steps packed into one halfword.
grep -q 'encoding=incremental' "$work/curve.log" ||
        fail 'curve/diagonal image did not select incremental encoding'
test "`wc -c < "$work/curve.dpic"`" -lt 6000 ||
        fail 'incremental curve encoding did not compact the display list'

if "$tool" "$work/alpha.png" "$work/alpha.dpic" >"$work/alpha.out" \
        2>"$work/alpha.log"; then
        fail 'transparent input was accepted'
fi
grep -q 'transparency is not allowed' "$work/alpha.log" ||
        fail 'transparent-input rejection diagnostic missing'

echo "$tag: PASS (polarity, Y reflection, lossless scan/incremental optimization, transparency)"
