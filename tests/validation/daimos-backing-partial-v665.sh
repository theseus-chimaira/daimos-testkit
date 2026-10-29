#!/bin/sh
# PDP-6 regression: fail the second physical write of a three-block span.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backing-partial-v665.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '%s\n' '.text' '.globl volume_tail_configure' \
        '.globl device_range_configure' '.globl backstore_read' \
        '.globl backstore_write' '.globl blockset_runtime_service_jump'
    sed -n '/^blockset_runtime_service_jump:$/,/^; Register provider ABI/p' \
        "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
    printf '%s\n' '.bss' '.globl device_region_map' '.globl volume_data_blocks' \
        '.globl backing_region_count' 'device_region_map: .block 1' \
        'volume_data_blocks: .block 1' 'backing_region_count: .block 1'
} > "$work/gateway.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 100000 --timeout 20 \
    --workdir "$work/run" --name daimos-backing-partial-v665 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/gateway.s" \
    "$DAIMOS_REPO/system/kernel/core/ret.s" \
    "$self/daimos-backing-partial-v665.s" > "$work/result.log" 2>&1 || {
        tail -40 "$work/result.log" >&2; exit 1;
    }
echo 'daimos-backing-partial-v665: PASS'
