#!/bin/sh
set -eu
: "${PDP10_PREFIX:?}"
: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-file-rename-v457-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin -fno-common -march=pdp6 \
  -I"$DAIMOS_REPO/system/kernel/core" -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/storage" \
  -S "$self/daimos-file-rename-native-v457.c" -o "$work/test.s"
{
  cat <<'ASM'
.text
kconst_14_14: .word 014,,014
.globl file_rename
ASM
  awk '/^file_rename:$/ {copy=1} /^; int file_chdir/ {copy=0} copy {print}' \
    "$DAIMOS_REPO/system/kernel/fs/file_runtime.s"
} > "$work/rename.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 1000000 --timeout 20 \
  --workdir "$work/run" --name daimos-file-rename-v457 \
  --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$work/test.s" "$work/rename.s" >/dev/null
printf '%s\n' 'daimos-file-rename-native-v457: PASS'
