#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
cc -DDAIMOS_TEST_HOST_WORD_ADDR -std=c99 -O2 -Wall -Wextra -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/mm" -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/fs" -I"$DAIMOS_REPO/system/kernel/storage" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_v1.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_layout_v36.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_owner_v37.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_teardown_v39.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_destroy_v084.c" \
  "$(dirname "$0")/test-v085.c" -o "$TMPDIR/packed-destroy-v085-test"
"$TMPDIR/packed-destroy-v085-test"

# Compile the dispatch entry with native PDP-6 ABI as well as host mock.
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 \
  -I"$DAIMOS_REPO/system/kernel" -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/proc" -I"$DAIMOS_REPO/system/kernel/mm" \
  -I"$DAIMOS_REPO/system/kernel/fs" -I"$DAIMOS_REPO/system/kernel/storage" \
  -I"$PDP10_PREFIX/include" -S -o "$TMPDIR/packed-destroy-v085-native.s" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_destroy_v084.c"
test -s "$TMPDIR/packed-destroy-v085-native.s"
