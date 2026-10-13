#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
cc -DDAIMOS_TEST_HOST_WORD_ADDR -std=c99 -O2 -Wall -Wextra -I"$DAIMOS_REPO/tools/host" -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/mm" -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/fs" -I"$DAIMOS_REPO/system/kernel/storage" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_v1.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_layout_v36.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_publish_v44.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_release_v43.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_owner_v37.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_restore_v46.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_evict_v077.c" \
  "$(dirname "$0")/test-v077.c" \
  "$DAIMOS_REPO/tools/host/d6codec-codec-v068.c" -o "$TMPDIR/packed-inline-v077-test"
"$TMPDIR/packed-inline-v077-test"
