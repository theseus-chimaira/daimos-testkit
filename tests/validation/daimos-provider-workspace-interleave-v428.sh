#!/bin/sh
# Run the genuine resident provider bridge with a deterministic wait oracle.
set -eu
: "${PDP10_PREFIX:?}"
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-provider-interleave-v428.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
{
    printf '%s\n' '.globl fs_provider_reg_call' '.globl fs_dtfs_service_jump' \
        '.globl fs_memfs_service_jump' '.globl fs_d6fs_service_jump' \
        '.globl fs_tsfs_service_jump'
    sed -n '/^fs_provider_reg_call:/,/^; KCORE memory-pressure bridge/p' \
        "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
} > "$work/gateway.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 300000 --timeout 15 \
    --workdir "$work/run" --name daimos-provider-workspace-interleave-v428 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-provider-workspace-interleave-v428.s" \
    "$work/gateway.s" > "$work/log" || { cat "$work/log"; exit 1; }
echo 'provider-workspace-interleave-v428: PASS (waiter clobber, shared lease, delayed dispatch)'
