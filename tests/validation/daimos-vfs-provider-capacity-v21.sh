#!/bin/sh
# Extract the exact native leaves. Force optional TENEX+ITS assembly enabled
# without changing the shipped native-only DTFS image build.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vfs-provider-v21.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
d6fs="$DAIMOS_REPO/system/kernel/fs/d6fs_runtime.s"
dtfs="$DAIMOS_REPO/system/kernel/fs/dtfs_runtime.s"
{
    printf '%s\n' '.text' '.globl d6fs_mres_reg_dispatch' \
        '.globl dtfs_patch_media' '.globl dtfs_personality' \
        '.globl dtfs_space'
    sed -n '/^d6fs_mres_reg_dispatch:/,/^; Return exact filesystem capacity/p' "$d6fs" | sed '$d'
    sed -n '/^dtfs_space:/,/^        \.data$/p' "$dtfs" | sed '$d'
    awk '/^        \.globl  dtfs_patch_media$/ { copy = 1 }
         /^ ; Mount ownership/ { exit }
         copy { print }' "$dtfs"
} > "$work/leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 400000 --timeout 15 \
    --workdir "$work/run" --name daimos-vfs-provider-v21 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-vfs-provider-capacity-v21.s" "$work/leaves.s" >/dev/null
echo 'vfs-provider-v21: PASS (mount26 reader/space, TENEX/ITS personality, bounds)'
