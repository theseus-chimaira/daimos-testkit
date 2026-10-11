#!/bin/sh
# A formatted D6FS with FCB 254 must not lose its allocated data blocks.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_TOOLS_REPO:?}" "${TMPDIR:?}"
w=$(mktemp -d "$TMPDIR/daimos-d6fsck-owner-width-20261010-v1.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$w/d6fsck" \
    "$DAIMOS_TOOLS_REPO/d6fsck.c"
printf '000000000000\n' > "$w/boot.words"
printf '123456701234\n' > "$w/data.words"
"$PDP10_PREFIX/bin/mkdsk" -n 4 -m clean -p "$w/boot.words" \
    -o "$w/disk" --d6fs-layout --logstore-blocks 0400 \
    --swap-tail-blocks 0400 --member-sectors 020000,020000,020000,020000
set -- -n 4 -d "$w/disk" -D /T:0755
i=0
while [ "$i" -lt 260 ]; do
    n=$(printf '%03d' "$i")
    set -- "$@" -f "/T/F$n:$w/data.words:644:words"
    i=$((i + 1))
done
# Installed formatter may still use the old checker internally.  The newly
# built checker, not the formatter's exit status, is under test here.
if "$PDP10_PREFIX/bin/mkd6fs" "$@" > "$w/format.log" 2>&1; then
    :
else
    grep -q 'post-format d6fsck failed' "$w/format.log"
fi
"$w/d6fsck" -n 4 -d "$w/disk" > "$w/check.log" 2>&1 || {
    cat "$w/check.log" >&2
    exit 1
}
grep -q ': clean' "$w/check.log"
printf '%s\n' 'PASS: D6FS FCB 254+ owner tracking retains allocated blocks'
