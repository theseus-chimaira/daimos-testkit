#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
cc -std=c99 -O2 -Wall -Wextra \
  -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/mm" \
  -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/storage" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_layout_v36.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_boot_v38.c" \
  "$(dirname "$0")/test.c" -o "$TMPDIR/packed-boot-v38-test"
"$TMPDIR/packed-boot-v38-test"
