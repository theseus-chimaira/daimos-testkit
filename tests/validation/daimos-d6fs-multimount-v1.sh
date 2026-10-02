#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source_file="$DAIMOS_REPO/system/kernel/fs/d6fs_runtime.s"
work="$TMPDIR/daimos-d6fs-multimount-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
{
        echo '.text'
        echo '.globl d6fs_mres_dispatch'
        sed -n '/^d6fs_mres_dispatch:/,/^d6fs_mres_create:/p' "$source_file" |
                sed '$d'
} > "$work/mount.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 1000000 --timeout 15 \
        --workdir "$work/run" --name daimos-d6fs-multimount-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-d6fs-multimount-v1.s" \
        "$work/mount.s" >/dev/null
printf '%s\n' 'd6fs-multimount: PASS (independent readers, identities, DRM-set backing, slots)'
