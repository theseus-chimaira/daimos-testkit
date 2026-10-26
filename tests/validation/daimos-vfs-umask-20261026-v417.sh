#!/bin/sh
# Run the production VFS CREATE entry on the PDP-6, with a stub provider.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vfs-umask-20261026-v417.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
source="$DAIMOS_REPO/system/kernel/fs/vfs.s"
{
    printf '%s\n' '.text' '.globl vfs_create' '.globl vfs_create_op'
    sed -n '/^        \.globl  vfs_create$/,/^; int vfs_create_op/p' "$source" | sed '$d'
} > "$work/vfs-create.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-vfs-umask-20261026-v417 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-vfs-umask-20261026-v417.s" "$work/vfs-create.s" >/dev/null
echo 'vfs-umask-v417: PASS (credential UMASK9, not obsolete FILE map)'
