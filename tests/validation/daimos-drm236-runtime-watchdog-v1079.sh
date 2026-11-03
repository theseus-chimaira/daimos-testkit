#!/bin/sh
# Run source-linked DRM236 runtime hardware-stall timeout, not a mock.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-drm236-runtime-watchdog-v1079.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
drm_src=${DRM_IO_SOURCE:-$DAIMOS_REPO/system/kernel/drivers/drm236_io.s}
sed -n '/^storage_clock_tick:/,/^; PI3 and PI5 each/p' \
    "$DAIMOS_REPO/system/kernel/storage/storage_router.s" |
    sed '$d' > "$work/clock.s"
{
    printf '.text\n.globl storage_clock_tick\n'
    printf '.globl storage_clock_dsk_jump\n'
    printf '.globl storage_clock_drm_jump\n'
    cat "$work/clock.s"
} > "$work/clock-all.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 25000 --timeout 15 \
    --workdir "$work/run" --name drm236-runtime-watchdog-v1079 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-drm236-runtime-watchdog-v1079.s" \
    "$drm_src" \
    "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
    "$DAIMOS_REPO/system/kernel/core/ret.s" \
    "$work/clock-all.s" > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'v1079: 300-tick DRM timeout, FIFO promotion, no double completion PASS'
