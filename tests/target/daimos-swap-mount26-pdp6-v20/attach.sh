#!/bin/sh
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-swap-mount26-attach-v20.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
"$cc" -std=c99 -Os -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -S "$self/attach.c" -o "$work/attach.s"
"$cc" -std=c99 -Os -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -S "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" \
    -o "$work/production-attach.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-swap-mount26-attach-v20 \
    --expect __test_exit=0 \
    "$self/../../validation/daimos-test-crt0-v1.s" \
    "$work/attach.s" "$work/production-attach.s" >/dev/null
echo 'swap-mount26-attach-v20: PASS (fifth bit, credential preservation, max fields and bounds)'
