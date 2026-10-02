#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-kfmt-u18-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 1000000 --timeout 15 \
    --workdir "$work/run" --name daimos-kfmt-u18-v1 \
    --expect __test_exit=0 \
    "$self/daimos-kfmt-u18-v1.s" \
    "$DAIMOS_REPO/system/kernel/core/kfmt_pdp6.s" >/dev/null
printf '%s\n' 'kfmt-u18: PASS (0..262143 packed SIXBIT width boundaries)'
