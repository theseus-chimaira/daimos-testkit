#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-v815.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 printf '.text\n.globl blockset_direct_configure\n.globl backstore_read\n.globl backstore_write\n.globl device_range_configure\n.globl backing_region_count\n.globl device_region_map\n.globl volume_data_blocks\n'
 sed -n '/^blockset_direct_configure:$/,/^blockset_tail_blocks:$/p' "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
} > "$work/leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name gateway-v815 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaves.s" "$self/daimos-backstore-gateway-native-v815.s" > "$work/log" 2>&1 || { tail -25 "$work/log" >&2; exit 1; }
echo 'v815: native PDP-6 production BACKSTORE gateway PASS'
