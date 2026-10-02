#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$TMPDIR/daimos-d6fs-super-recovery-v1-$$
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

cc ${CFLAGS:--Wall -Wextra -O2 -std=c99} \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    "$DAIMOS_REPO/system/kernel/fs/d6fs_super_boot.c" \
    "$self/daimos-d6fs-super-recovery-v1.c" \
    -o "$work/d6fs-super-recovery"

"$work/d6fs-super-recovery"
printf '%s\n' 'd6fs-super-recovery: PASS (newest DIRTY rejected; torn alternate CLEAN-safe)'
