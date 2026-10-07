#!/bin/sh
set -eu

: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=mkd6fs-encoding-v1
work="$TMPDIR/$tag-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/disk"
build="$work/build"
bin="$build/tools/host"

make -C "$PDP10_TOOLS_REPO" build BUILD_ROOT="$build" >/dev/null
printf '0:RESPAWN:/SYSTEM/EXEC/LOGIN\n' > "$work/inittab"
printf '0\n' > "$work/boot.words"

"$bin/mkdsk" -n 1 -m clean -p "$work/boot.words" -o "$work/disk" \
    --d6fs-layout --logstore-blocks 010 --swap-tail-blocks 010 >/dev/null
if "$bin/mkd6fs" -n 1 -d "$work/disk" \
    -D /CONFIG:0755 \
    -f "/CONFIG/INITTAB:$work/inittab:644:text" \
    >"$work/out" 2>"$work/err"; then
        echo "$tag: obsolete :text encoding unexpectedly accepted" >&2
        exit 1
fi
grep -q 'unsupported encoding' "$work/err" || {
        cat "$work/err" >&2
        echo "$tag: expected unsupported-encoding diagnostic missing" >&2
        exit 1
}

printf '%s\n' "$tag: PASS"
