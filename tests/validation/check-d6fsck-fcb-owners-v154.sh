#!/bin/sh
# A D6FS FCB index >=254 has owner ID >=256. The checker must retain all
# owner bits or it will mistake referenced payload blocks for leaked blocks.
set -eu
: "${PDP10_TOOLS_REPO:?Set PDP10_TOOLS_REPO to pdp10-tools source}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"
: "${TMPDIR:?Set TMPDIR}"

work="$TMPDIR/d6fsck-fcb-owners-v154-$$"
mkdir -p "$work/bin" "$work/disk"
if [ "${DAIMOS_KEEP_TEST_LOGS:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "D6FS owner test logs: $work"
fi

# Keep the same mkd6fs writer; replace only its sibling checker under test.
# mkd6fs invokes ./d6fsck beside its own executable after writing metadata.
cc -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/bin/d6fsck" "$PDP10_TOOLS_REPO/d6fsck.c"
cp "$PDP10_PREFIX/bin/mkd6fs" "$work/bin/mkd6fs"
: > "$work/boot.words"
printf '\001\000\000\000\000\000\000\000' > "$work/one.binwords"

"$PDP10_PREFIX/bin/mkdsk" -n 1 -m clean -p "$work/boot.words" \
    -o "$work/disk" --d6fs-layout --logstore-blocks 0 \
    --swap-tail-blocks 0 --spare-blocks 0 \
    --member-sectors 020000 > "$work/mkdsk.log" 2>&1

set -- -n 1 -d "$work/disk"
i=1
while [ "$i" -le 260 ]; do
    name=$(printf 'FILE%03d' "$i")
    set -- "$@" -f "/$name:$work/one.binwords:0644:binwords"
    i=$((i + 1))
done
"$work/bin/mkd6fs" "$@" > "$work/mkd6fs.log" 2>&1 || {
    tail -30 "$work/mkd6fs.log" >&2
    echo 'FAIL: mkd6fs rejected consistent >254-FCB filesystem' >&2
    exit 1
}
"$work/bin/d6fsck" -n 1 -d "$work/disk" > "$work/check.log" 2>&1 || {
    tail -30 "$work/check.log" >&2
    exit 1
}
grep -F 'clean' "$work/check.log" >/dev/null || {
    cat "$work/check.log" >&2
    exit 1
}
echo 'PASS: D6FS checker preserves owner IDs above 255 for 260 file nodes'
