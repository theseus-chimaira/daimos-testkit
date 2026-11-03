#!/bin/sh
# Test the production DRM driver when three requests overlap.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-drm236-queue-full-v1080.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1080 work: $work"; fi' EXIT HUP INT TERM
driver=${DRM_IO_SOURCE:-$DAIMOS_REPO/system/kernel/drivers/drm236_io.s}
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 18000 --timeout 15 \
    --workdir "$work/run" --name drm236-queue-full-v1080 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-drm236-queue-full-v1080.s" \
    "$driver" \
    "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
    "$DAIMOS_REPO/system/kernel/core/ret.s" > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'v1080: third DRM request sleeps on active then claims freed DMA PASS'
