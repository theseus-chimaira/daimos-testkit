#!/bin/sh
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to DAIMOS checkout}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bin="$TMPDIR/daimos-dsh-parser-direct-20261011-v1-$$"
trap 'rm -f "$bin"' EXIT HUP INT TERM
cc -std=c89 -O2 -Wall -Wextra \
  -I"$DAIMOS_REPO/userland/dsh" -I"$DAIMOS_REPO/userland/libc" \
  -I"$DAIMOS_REPO/system/kernel/core" -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/storage" -I"$DAIMOS_REPO/system/kernel/mm" -I"$DAIMOS_REPO/system/kernel/drivers" -I"$DAIMOS_REPO/system/kernel/modules" -I"$DAIMOS_REPO/system/kernel/proc" -I"$DAIMOS_REPO/system/kernel/boot" \
  "$base/daimos-dsh-parser-direct-20261011-v1.c" \
  "$DAIMOS_REPO/userland/dsh/dsh_s6.c" \
  "$DAIMOS_REPO/userland/dsh/dsh_lex.c" \
  "$DAIMOS_REPO/userland/dsh/dsh_parse.c" -o "$bin"
"$bin"
