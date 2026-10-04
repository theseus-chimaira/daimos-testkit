#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-dtfs-create-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin -fno-common \
    -march=pdp6 -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -S "$self/daimos-dtfs-create-v1.c" -o "$work/oracle.s"

{
    printf '%s\n' '.set DTFS_ENABLE_TENEX,1' '.set DTFS_ENABLE_ITS,1' \
        '.set DTFS_ENABLE_FOREIGN,1' '.text'
    cat <<'ASM'
dtfs_restore4:
        pop 17,013
dtfs_restore3:
        pop 17,012
dtfs_restore2:
        pop 17,011
dtfs_restore1:
        pop 17,010
        popj 17,
ASM
    printf '%s\n' '.globl dtfs_create'
    awk '/^dtfs_create:$/ {copy=1} /^[[:space:]]*\.globl[[:space:]]+dtfs_rename$/ {copy=0} copy {print}' \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_runtime.s"
} > "$work/create.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 2000000 --timeout 20 \
    --workdir "$work/run" --name daimos-dtfs-create-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/oracle.s" "$work/create.s" >/dev/null
printf '%s\n' 'dtfs-create: PASS (native/TENEX/ITS success and rollback paths)'
