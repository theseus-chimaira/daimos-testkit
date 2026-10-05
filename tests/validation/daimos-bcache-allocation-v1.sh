#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-bcache-allocation-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 1000000 --timeout 15 \
    --workdir "$work/run" --name daimos-bcache-allocation-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-bcache-allocation-v1.s" \
    "$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s" >/dev/null
printf '%s\n' 'bcache-allocation: PASS (129-word private slab allocates and reclaims)'
