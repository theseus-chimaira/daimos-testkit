#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
: "${SIMH_PDP6:?SIMH_PDP6 must be set to the Type-167/236 PDP-6 simulator}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-drm236-online-v1-$$"
media0="$work/dr0.drm"
media1="$work/dr1.drm"
media3="$work/dr3.drm"
ini="$work/drm.ini"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

cat > "$ini" <<EOF2
set DP enabled
set DR enabled
set DR0 enabled
set DR0 WRITEENABLED
attach -q -n DR0 $media0
set DR1 enabled
set DR1 WRITEENABLED
attach -q -n DR1 $media1
set DR3 enabled
set DR3 WRITEENABLED
attach -q -n DR3 $media3
EOF2

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 20 --workdir "$work/run" \
        --name daimos-drm236-online-v1 --ini "$ini" \
        --expect __test_exit=0 --expect fail_id=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-drm236-online-v1.s" \
        "$DAIMOS_REPO/system/kernel/drivers/drm236.s" \
        "$DAIMOS_REPO/system/kernel/drivers/drm236_io.s" \
        "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
        "$DAIMOS_REPO/system/kernel/core/ret.s" \
        "$self/daimos-drm236-online-stubs-v1.s" >/dev/null

printf '%s\n' 'drm236-online: PASS (production Type-167/236 block I/O plus queued runtime handoff)'
