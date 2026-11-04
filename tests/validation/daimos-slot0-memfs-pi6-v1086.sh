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
    printf '.globl memfs_mres_reg_dispatch\n.globl mm_pin\n'
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

fixture="$self/daimos-slot0-memfs-pi6-v1086.s"
mode=${DAIMOS_V1108_XIP_MM:-0}
case "$mode" in
    0) ;;
    1) fixture="$self/daimos-xip-physical-retry-v1108.s" ;;
    *) echo 'v1108: invalid XIP MM mode' >&2; exit 2 ;;
esac
if [ "$mode" = 1 ]; then
    # Both unsafe variants use the identical production MM leaf and
    # physical fixture. Only the MEMFS-owned XIP ref update is changed.
    python3 - "$work/leaf.s" "$work" <<'PY'
from pathlib import Path
import sys

leaf = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
mutants = {
    'drop-ref-on-unpin-error': (
        '        jumpn   1,memfs_xip_unpin_base_fail\n'
        '        setzm   (011)',
        '        jumpe   1,memfs_xip_unpin_base_fail\n'
        '        setzm   (011)'),
    'retain-ref-on-unpin-success': (
        '        setzm   (011)\n'
        '        jrst    memfs_xip_unpin_base_ok',
        '        jrst    memfs_xip_unpin_base_ok\n'
        '        jrst    memfs_xip_unpin_base_ok'),
}
for name, (before, after) in mutants.items():
    if leaf.count(before) != 1:
        raise SystemExit('v1108: mutation anchor changed: ' + name)
    (work / ('unsafe-' + name + '.s')).write_text(
        leaf.replace(before, after, 1))
PY
fi
run_case() {
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 250000 --timeout 25 \
        --workdir "$work/run-$name" --name "slot0-memfs-v1108-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$fixture" > "$work/log-$name" 2>&1
}
if ! run_case positive "$work/leaf.s"; then
        tail -75 "$work/log-positive" >&2
        exit 1
fi
if [ "$mode" = 1 ]; then
    for mutant in drop-ref-on-unpin-error retain-ref-on-unpin-success; do
        if run_case "$mutant" "$work/unsafe-$mutant.s"; then
            echo "v1108: unsafe $mutant mutation PASSED" >&2
            exit 1
        fi
    done
    echo 'v1108: real XIP MM -4 refusal, exact pin/ownership retry, two unsafe mutations rejected PASS'
else
    echo 'v1086: slot-0 XIP bypasses foreign provider lease, unpins via real MM, no clock wait PASS'
fi
