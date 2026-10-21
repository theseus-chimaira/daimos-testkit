#!/bin/sh
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
out="$TMPDIR/daimos-dsh-angle-lex-20261021-v1-$$"
trap 'rm -f "$out"' EXIT HUP INT TERM
cc -std=c99 -O2 -Wall -Wextra \
  -I"${PDP10_PREFIX:-$HOME/cross}/include" \
  -I"$DAIMOS_REPO/userland/dsh" -I"$DAIMOS_REPO/userland/libc" \
  -I"$DAIMOS_REPO/system/kernel/core" -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/storage" -I"$DAIMOS_REPO/system/kernel/mm" \
  -I"$DAIMOS_REPO/system/kernel/drivers" -I"$DAIMOS_REPO/system/kernel/modules" \
  -I"$DAIMOS_REPO/system/kernel/proc" -I"$DAIMOS_REPO/system/kernel/boot" \
  "$(dirname "$0")/daimos-dsh-angle-lex-20261021-v1.c" \
  "$DAIMOS_REPO/userland/dsh/dsh_s6.c" \
  "$DAIMOS_REPO/userland/dsh/dsh_lex.c" -o "$out"
"$out"
