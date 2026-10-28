#!/bin/sh
# Host-only safety regression; never point this test at a real disk image.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mkauxstore-v636.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
tool="$DAIMOS_REPO/build/tools/host/mkauxstore"
image="$work/aux.dsk"
"$tool" --blank "$image" --blocks 0200
ln -s "$image" "$work/link"
if "$tool" --inspect "$work/link" >/dev/null 2>&1; then
        echo 'symlinked image unexpectedly accepted' >&2; exit 1
fi
if "$tool" --blank "$image" --blocks 0200 >/dev/null 2>&1; then
        echo 'blank unexpectedly overwrote existing image' >&2; exit 1
fi
args='--d6fs-base 1 --d6fs-blocks 020 --d6fs-super-a 0 --d6fs-super-b 1 --backstore-blocks 010 --logstore-blocks 0 --cache-blocks 0147'
cp "$image" "$work/original"
# D6FS bytes are outside the formatting scope and must survive unchanged.
printf '\252' | dd of="$image" bs=1 seek=$((010 * 1024)) conv=notrunc 2>/dev/null
dd if="$image" of="$work/d6fs-before" bs=1024 skip=1 count=16 2>/dev/null
cp "$image" "$work/original"
# Word splitting is deliberate for the fixed test arguments.
# shellcheck disable=SC2086
"$tool" -i "$image" --dry-run $args > "$work/plan"
cmp "$image" "$work/original"
if "$tool" -i "$image" $args > /dev/null 2>&1; then
        echo 'format without confirmation succeeded' >&2; exit 1
fi
cmp "$image" "$work/original"
"$tool" -i "$image" --confirm-destructive $args > /dev/null
dd if="$image" of="$work/d6fs-after" bs=1024 skip=1 count=16 2>/dev/null
cmp "$work/d6fs-before" "$work/d6fs-after"
"$tool" --inspect "$image" > "$work/inspect"
grep -q 'BACKSTORE 21+10' "$work/inspect"
cp "$image" "$work/formatted"
if "$tool" -i "$image" --confirm-destructive $args >/dev/null 2>&1; then
        echo 'reformat unexpectedly succeeded' >&2; exit 1
fi
cmp "$image" "$work/formatted"
# A descriptor containing only non-36-bit high bits is still nonempty.
"$tool" --blank "$work/dirty-header" --blocks 0200
printf '\200' | dd of="$work/dirty-header" bs=1 seek=7 conv=notrunc 2>/dev/null
if "$tool" -i "$work/dirty-header" --confirm-destructive $args >/dev/null 2>&1; then
        echo 'dirty descriptor unexpectedly accepted' >&2; exit 1
fi
# Unknown nonzero data anywhere in the future backing range is protected.
"$tool" --blank "$work/nonempty" --blocks 0200
printf '\377' | dd of="$work/nonempty" bs=1 seek=$((040 * 1024)) conv=notrunc 2>/dev/null
cp "$work/nonempty" "$work/nonempty.original"
if "$tool" -i "$work/nonempty" --confirm-destructive $args >/dev/null 2>&1; then
        echo 'nonempty target unexpectedly accepted' >&2; exit 1
fi
cmp "$work/nonempty" "$work/nonempty.original"
echo 'daimos-mkauxstore-safety-v636: PASS'
