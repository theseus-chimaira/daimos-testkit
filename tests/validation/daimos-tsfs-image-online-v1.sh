#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-tsfs-image-online-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
build="$work/build"
bin="$build/tools/host"

make -C "$PDP10_TOOLS_REPO" build BUILD_ROOT="$build" >/dev/null
"$bin/mktsfs" -n 1 -i 1:2 -g 1 -o "$work/member"

cat > "$work/dtc.ini" <<EOF2
set DCT enabled
set DTC enabled
set DTC0 enabled
set DTC DCT=4
attach -q DTC0 $work/member0.dta
EOF2

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 25 --workdir "$work/run" --name daimos-tsfs-image \
    --ini "$work/dtc.ini" --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-tsfs-image-online-v1.s" \
    "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
    "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
    "$self/daimos-dtc-stream-online-stubs-v1.s" >/dev/null

printf '%s\n' 'tsfs-image-online: PASS (host image readable through production Type-551 driver)'
