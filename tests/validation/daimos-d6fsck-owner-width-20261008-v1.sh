#!/bin/sh
# Exercise owner identifiers beyond the old eight-bit d6fsck map limit.
set -eu

PDP10_PREFIX=${PDP10_PREFIX:-$HOME/git/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-d6fsck-owner-width-20261008-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

mkdsk="$PDP10_PREFIX/bin/mkdsk"
mkd6fs="$PDP10_PREFIX/bin/mkd6fs"
d6fsck="$PDP10_PREFIX/bin/d6fsck"

# One physical member suffices to prove the FCB-owner width; a tiny file
# in FCB index 254 was previously assigned owner 256, truncated to zero.
printf '000000000000\n' > "$work/boot.words"
"$mkdsk" -n 1 -m clean -p "$work/boot.words" -o "$work/disk" \
    --d6fs-layout --logstore-blocks 0 --swap-tail-blocks 0 \
    --spare-blocks 0 --member-sectors 0130000 > "$work/mkdsk.log" 2>&1 || {
    cat "$work/mkdsk.log" >&2
    exit 1
}
printf '\000\000\000\000\000\000\000\000' > "$work/one-word.bin"

set -- -n 1 -d "$work/disk"
i=0
while [ "$i" -lt 260 ]; do
    name=$(printf 'N%04d' "$i")
    set -- "$@" -f "/$name:$work/one-word.bin:444:binwords"
    i=$((i + 1))
done
"$mkd6fs" "$@" > "$work/mkd6fs.log" 2>&1 || {
    cat "$work/mkd6fs.log" >&2
    exit 1
}
"$d6fsck" -n 1 -d "$work/disk" > "$work/d6fsck.log" 2>&1 || {
    cat "$work/d6fsck.log" >&2
    exit 1
}
grep -q ': clean$' "$work/d6fsck.log"
echo 'daimos-d6fsck-owner-width-20261008-v1: PASS'
