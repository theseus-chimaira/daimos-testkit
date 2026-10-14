#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
out="$TMPDIR/proc-uarea-v138"
mkdir -p "$out"
{
    printf '%s\n' '.equ PROC_SWAP_BACKING_OFFSET,0406' \
        '.equ PROC_SWAP_TEXT_SHIFT,026' \
        '.equ PROC_SWAP_TEXT_MASK,037777' \
        '.equ PROC_SWAP_PROVIDER_SHIFT,024' \
        '.equ PROC_SWAP_MOUNT_SHIFT,022' \
        '.equ EXEC_DXR_F_COMPRESSED,0100000' \
        '.equ EXEC_USER_ORIGIN,020'
    cat "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s"
} > "$out/proc_pure_backing_v138.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --set 'set cpu 128k' \
  --exec-mode go --start 1000 --timeout 30 --workdir "$out/run" \
  --name proc-uarea-v138 --expect __test_exit=0 \
  "$(dirname "$0")/../../../validation/d6codec-native-v051/crt_stack_v051.s" \
  "$(dirname "$0")/test-v138.s" "$out/proc_pure_backing_v138.s"
