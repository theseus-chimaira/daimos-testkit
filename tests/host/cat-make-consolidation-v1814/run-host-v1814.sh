#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must name the source checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/cat-make-host-v1814.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

set --
for dir in boot core drivers fs mm modules proc storage; do
    set -- "$@" "-I$DAIMOS_REPO/system/kernel/$dir"
done
"${HOST_CC:-cc}" -std=c89 -O2 -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections -Wl,--gc-sections \
    "$@" -I"$DAIMOS_REPO/userland/libc" \
    -I"$PDP10_PREFIX/include" \
    -o "$work/cat-v1814" \
    "$here/test-cat-stream-v1814.c" \
    "$DAIMOS_REPO/userland/libc/cat_stream_v1814.c" \
    "$DAIMOS_REPO/userland/libc/text.c" \
    "$DAIMOS_REPO/userland/libc/u.c"
"$work/cat-v1814"
