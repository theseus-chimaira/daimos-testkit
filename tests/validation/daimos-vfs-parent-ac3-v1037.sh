#!/bin/sh
# Native VFS test extracts the actual mounted-parent assembly path.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-vfs-parent-ac3-v1037-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
src="$DAIMOS_REPO/system/kernel/fs/vfs.s"
{
    echo '.globl vfs_parent'
    sed -n '/^vfs_parent:/,/^; int vfs_parent_name/p' "$src" | \
        sed '$d'
} > "$work/vfs-parent.s"
test -s "$work/vfs-parent.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 15 \
    --workdir "$work/run" --name daimos-vfs-parent-ac3-v1037 \
    --expect __test_exit=0 \
    "$here/daimos-test-crt0-v1.s" \
    "$here/daimos-vfs-parent-ac3-v1037.s" \
    "$work/vfs-parent.s"
echo 'PASS: VFS mount-parent path preserves AC3 and resolves root'
