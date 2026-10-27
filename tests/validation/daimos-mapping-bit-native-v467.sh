#!/bin/sh
set -eu
: "${PDP10_PREFIX:?}"
: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-mapping-bit-v467-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin \
  -fno-common -march=pdp6 -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/fs" -I"$DAIMOS_REPO/system/kernel/storage" \
  -S "$self/daimos-mapping-bit-native-v467.c" -o "$work/test.s"
{
  printf '%s\n' '.text' '.globl vm_user_mapping_hold' \
    '.globl vm_user_mapping_release'
  sed -n '/^vm_user_mapping_hold:$/,/^\/\*\* @brief Program the PDP-6 APR/p' \
    "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" | sed '$d'
} > "$work/hold.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 200000 --timeout 15 \
  --workdir "$work/run" --name daimos-mapping-bit-v467 --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$work/test.s" "$work/hold.s" \
  "$self/daimos-mapping-bit-native-stubs-v467.s" >/dev/null
printf '%s\n' 'daimos-mapping-bit-native-v467: PASS'
