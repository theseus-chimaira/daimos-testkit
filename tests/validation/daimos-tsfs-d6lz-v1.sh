#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-tsfs-d6lz-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 20 --workdir "$work/run" --name daimos-tsfs-d6lz \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-tsfs-d6lz-v1.s" \
    "$DAIMOS_REPO/system/kernel/core/d6lz_pdp6.s" \
    "$DAIMOS_REPO/system/kernel/fs/tsfs_runtime.s" >/dev/null
printf '%s\n' 'daimos-tsfs-d6lz-v1: PASS (D6LZ restart integration and transient free)'
