#!/bin/sh
# Compile and execute the exact INIT terminal-presence function on the host.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-init-tty-presence-v23c.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source="$DAIMOS_REPO/userland/init/init.c"
leaf="$work/daimos-init-tty-presence-v23c-leaf.inc"
printf 'static int\n' > "$leaf"
sed -n '/^init_tty_input_present_v23c(unsigned int tty)$/,/^}$/p' \
    "$source" >> "$leaf"
grep -q '^init_tty_input_present_v23c(unsigned int tty)$' "$leaf"
grep -q 'return st.type == VFS_TYPE_CHAR;' "$leaf"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
    -I"$work" -I"$DAIMOS_REPO/userland/libc" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$PDP10_PREFIX/include" \
    "$self/daimos-init-tty-presence-v23c.c" -o "$work/test"
"$work/test"
