#!/bin/sh
# Extract and run the exact native FILE leaves, not a rewritten C oracle.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-file-mountext-v19.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source="$DAIMOS_REPO/system/kernel/fs/file_runtime.s"
{
    printf '%s\n' '.text' '.globl file_find' '.globl file_new_fd' \
        '.globl file_close' '.globl file_dup' '.globl file_dup2' \
        '.globl file_lock' '.globl file_unlock_mount'
    sed -n '/^        \.globl  file_node_from_fd/,/^file_check_access:/p' "$source" | sed '$d'
    sed -n '/^file_close:/,/^; int file_dup/p' "$source" | sed '$d'
    sed -n '/^file_dup:/,/^; void file_close_all/p' "$source" | sed '$d'
    sed -n '/^file_find:/,/^; kword_t file_seek/p' "$source" | sed '$d'
} > "$work/file-leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 15 \
    --workdir "$work/run" --name daimos-file-mountext-v19 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-file-mountext-v19.s" "$work/file-leaves.s" >/dev/null
echo 'file-mountext-v19: PASS (26-mount vnode, lock, DUP/DUP2, close and unmount)'
