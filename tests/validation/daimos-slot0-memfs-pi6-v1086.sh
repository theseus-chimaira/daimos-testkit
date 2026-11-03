#!/bin/sh
# PDP-6 native execution of the slot-0 MEMFS XIP provider gateway.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-slot0-memfs-pi6-v1086.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

{
    printf '.text\n.globl fs_provider_reg_call\n.globl memfs_mres_xip_release\n'
    printf '.globl memfs_mres_reg_dispatch\n'
    printf '.equ MEMFS_NODE_DATA,6\n.equ MEMFS_XIP_SLOTS,4\n'
    printf '.equ MM_PIN_FIELD,03770000000\n.equ MM_PIN_ONE,010000000\n'
    sed -n '/^fs_provider_reg_call:$/,/^; KCORE memory-pressure bridge/p' \
        "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d' | \
        sed '/^fs_memfs_service_jump:$/,/^fs_dtfs_service_jump:$/s/jrst    fs_mres_no_service/jrst    xip_service_v1086/'
    sed -n '/^memfs_mres_xip_release:$/,/^; SPACE returns total/p' \
        "$DAIMOS_REPO/system/kernel/fs/memfs_runtime.s" | sed '$d'
    sed -n '/^memfs_mres_dispatch:$/,/^; AC1=vnode, AC2=/p' \
        "$DAIMOS_REPO/system/kernel/fs/memfs_runtime.s" | sed '$d'
    sed -n '/^memfs_xip_unpin_base:$/,/^; int memfs_xip_owns_base/p' \
        "$DAIMOS_REPO/system/kernel/fs/memfs_data_pdp6.s" | sed '$d'
    sed -n '/^memfs_xip_owns_base:$/,/^; int memfs_data_ensure/p' \
        "$DAIMOS_REPO/system/kernel/fs/memfs_data_pdp6.s" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/leaf.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 25 \
    --workdir "$work/run" --name slot0-memfs-pi6-v1086 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-slot0-memfs-pi6-v1086.s" > "$work/log" 2>&1 || {
        tail -75 "$work/log" >&2
        exit 1
    }
echo 'v1086: slot-0 XIP bypasses foreign provider lease, unpins via real MM, no clock wait PASS'
