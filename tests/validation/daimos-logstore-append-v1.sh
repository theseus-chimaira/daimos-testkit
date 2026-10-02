#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-logstore-append-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 2000000 --timeout 15 \
    --workdir "$work/run" --name daimos-logstore-append-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-logstore-append-v1.s" \
    "$DAIMOS_REPO/system/kernel/storage/logstore_runtime.s" >/dev/null
printf '%s\n' 'daimos-logstore-append-v1: PASS (commit-last append, cursor advance, raw read/status)'
