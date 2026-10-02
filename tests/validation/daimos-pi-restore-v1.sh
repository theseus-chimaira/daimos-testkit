#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-pi-restore-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 1000000 --timeout 15 \
    --workdir "$work/run" --name daimos-pi-restore-v1 \
    --expect __test_exit=0 \
    "$self/daimos-pi-restore-v1.s" \
    "$self/daimos-pi-restore-v1-stubs.s" \
    "$DAIMOS_REPO/system/kernel/core/kcore_pi_pdp6.s" >/dev/null

printf '%s\n' 'daimos-pi-restore-v1: PASS (disabled and enabled PI state restored)'
