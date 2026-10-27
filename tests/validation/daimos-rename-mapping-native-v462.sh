#!/bin/sh
set -eu
: "${PDP10_PREFIX:?}"
: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-rename-mapping-v462-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin -fno-common -march=pdp6 \
  -I"$DAIMOS_REPO/system/kernel/core" -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/storage" \
  -S "$self/daimos-rename-mapping-native-v462.c" -o "$work/test.s"
{
  printf '%s\n' '.text' '.globl native_sys_two_paths'
  awk '/^native_sys_two_paths:$/ {copy=1} /^%L90:$/ {copy=0} copy {print}' \
    "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s"
} > "$work/mapper.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 1000000 --timeout 20 \
  --workdir "$work/run" --name daimos-rename-mapping-v462 \
  --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$work/test.s" "$work/mapper.s" \
  "$self/daimos-rename-mapping-native-v462.s" >/dev/null
printf '%s\n' 'daimos-rename-mapping-native-v462: PASS'
