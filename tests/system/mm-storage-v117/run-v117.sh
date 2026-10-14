#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-"$HOME/tmp"}
out="$TMPDIR/daimos-mm-storage-v117"
mkdir -p "$out"
cc -std=c99 -O2 -Wall -Wextra -Werror \
  -I"$DAIMOS_REPO/system/kernel" \
  -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/mm" \
  -I"$DAIMOS_REPO/system/kernel/core" \
  -o "$out/test-v117" \
  "$(dirname "$0")/test-v117.c" \
  "$DAIMOS_REPO/system/kernel/proc/proc_storage_map_v28.c"
"$out/test-v117"
