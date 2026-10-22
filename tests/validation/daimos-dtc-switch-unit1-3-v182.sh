#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-dtc-switch-unit1-3-v182-$$"
media="$work/dtc3.tap"
ini="$work/dtc.ini"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
cat > "$ini" <<EOF2
set DCT enabled
set DTC enabled
set DTC1 enabled
set DTC3 enabled
set DTC DCT=4
attach -q -n DTC1 $work/dtc1.tap
attach -q -n DTC3 $media
EOF2
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 25 --workdir "$work/run" --name daimos-dtc-stream \
    --ini "$ini" --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-dtc-switch-unit1-3-v182.s" \
    "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
    "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
    "$self/daimos-dtc-stream-online-stubs-v1.s" >/dev/null
printf '%s\n' 'dtc-switch-unit1-3-v182: PASS (production two-block Type-551 counted write/read)'
