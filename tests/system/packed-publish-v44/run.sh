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
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_release_v43.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_publish_v44.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_boot_v38.c" \
  "$(dirname "$0")/test.c" -o "$TMPDIR/packed-publish-v44-test"
"$TMPDIR/packed-publish-v44-test"
