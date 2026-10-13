#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
cc -DDAIMOS_TEST_HOST_WORD_ADDR -std=c99 -O2 -Wall -Wextra -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/mm" -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/fs" -I"$DAIMOS_REPO/system/kernel/storage" \
  "$DAIMOS_REPO/system/kernel/proc/proc_packed_v1.c" \
  "$(dirname "$0")/test.c" -o "$TMPDIR/packed-evict-v32-test"
"$TMPDIR/packed-evict-v32-test"
