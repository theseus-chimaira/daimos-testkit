#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-recovery-select-v671.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
"${CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    "$DAIMOS_REPO/system/kernel/boot/d6fs_super_boot.c" \
    "$self/daimos-d6fs-recovery-select-v671.c" -o "$work/test"
"$work/test"
