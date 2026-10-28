#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
out="$TMPDIR/daimos-time1858-v614-$$"
trap 'rm -f "$out"' EXIT HUP INT TERM
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
  -I"$DAIMOS_REPO/userland/libc" \
  -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/storage" \
  -I"$HOME/cross/include" \
  "$DAIMOS_REPO/userland/libc/time1858.c" \
  "$(dirname "$0")/daimos-time1858-v614.c" -o "$out"
"$out"
