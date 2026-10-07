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
magick -size 2048x2048 xc:none "$work/alpha.png"

"$tool" "$work/black.png" "$work/black.dpic" 2>"$work/black.log"
"$tool" "$work/white.png" "$work/white.dpic" 2>"$work/white.log"
"$tool" "$work/top.png" "$work/top.dpic" 2>"$work/top.log"

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

if "$tool" "$work/alpha.png" "$work/alpha.dpic" >"$work/alpha.out" \
        2>"$work/alpha.log"; then
        fail 'transparent input was accepted'
fi
grep -q 'transparency is not allowed' "$work/alpha.log" ||
        fail 'transparent-input rejection diagnostic missing'

echo "$tag: PASS (polarity, Y reflection, vector output, transparency)"
