#!/bin/sh
# Compile the native RM C implementation with the actual KCC cross compiler.
set -eu
: "${DAIMOS_REPO:?}"
: "${KCC_REPO:?}"
export TMPDIR=${TMPDIR:-"$HOME/tmp"}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-rm-kcc-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cd "$DAIMOS_REPO"
"$KCC_REPO/build/kcc" -Pgnu99 -x=pdp6 -m=gas \
    -Iuserland/libc -Iuserland/exec \
    -Isystem/kernel/boot -Isystem/kernel/core \
    -Isystem/kernel/fs -Isystem/kernel/proc \
    -Isystem/kernel/storage -Isystem/kernel/drivers -Itools/host \
    -DDAIMOS_CMD_PROGRAM=5 -S userland/exec/commands.c \
    -o "$work/commands.s" > "$work/kcc.log" 2>&1 || {
        cat "$work/kcc.log" >&2
        exit 1
    }
if grep -Ei '(errors? detected|can.t open include|undefined identifier)' \
    "$work/kcc.log"; then
    exit 1
fi
test -s "$work/commands.s"
echo 'PASS: native RM cross-compilation with KCC'
