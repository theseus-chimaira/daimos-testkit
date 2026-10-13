#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
cc -DPROC_UAREA_RELEASE_PDP6_ASM -DPROC_TTY_RELEASE_PDP6_ASM -std=c99 -O2 -Wall -Wextra -ffunction-sections -fdata-sections \
  -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/mm" \
  -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/storage" \
  -I"$DAIMOS_REPO/system/kernel/drivers" \
  -I"$DAIMOS_REPO/system/kernel/ipc" \
  "$DAIMOS_REPO/system/kernel/proc/proc.c" \
  "$(dirname "$0")/test.c" -Wl,--gc-sections \
  -o "$TMPDIR/proc-abort-transition-v40-test"
"$TMPDIR/proc-abort-transition-v40-test"
