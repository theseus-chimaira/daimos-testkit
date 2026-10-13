#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"

mkdsk=$PDP10_PREFIX/bin/mkdsk
mkd6fs=$PDP10_PREFIX/bin/mkd6fs
d6fsck=$PDP10_PREFIX/bin/d6fsck

for t in "$mkdsk" "$mkd6fs" "$d6fsck"; do
    test -x "$t" || { echo "missing tool: $t" >&2; exit 1; }
done

work=$TMPDIR/d6fs-fcb-headroom-v1-$$
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
printf '0\n' > "$work/boot.words"

"$mkdsk" -n 1 -m clean -p "$work/boot.words" -o "$work/disk" \
    --d6fs-layout --logstore-blocks 010 --swap-tail-blocks 010 \
    --spare-blocks 010 >/dev/null

set --
i=0
while [ "$i" -lt 70 ]; do
    set -- "$@" -D "/D$i:755"
    i=$((i + 1))
done
"$mkd6fs" -n 1 -d "$work/disk" "$@" >"$work/mk.out" 2>"$work/mk.err"
"$d6fsck" -n 1 -d "$work/disk" >"$work/check.out" 2>"$work/check.err"

# 70 explicit directories plus the root make 71 live nodes.  Writable images
# must retain at least 64 free object slots for compiler/assembler scratch and
# self-host build products.  FCB allocation is rounded to 8 records per block.
fcbs=$(cat "$work/check.out" "$work/check.err" | sed -n 's/.*blocks, \([0-9][0-9]*\) FCBs.*/\1/p' | tail -n 1)
test -n "$fcbs" || {
    cat "$work/mk.out" "$work/mk.err" "$work/check.out" "$work/check.err" >&2
    echo "cannot determine D6FS FCB count" >&2
    exit 1
}
test "$fcbs" -ge 135 || {
    echo "insufficient D6FS FCB headroom: $fcbs slots for 71 initial nodes" >&2
    exit 1
}

echo "D6FS FCB headroom regression passed: $fcbs slots for 71 initial nodes"
