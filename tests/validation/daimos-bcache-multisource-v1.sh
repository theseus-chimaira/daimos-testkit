#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source_file="$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s"
work="$TMPDIR/daimos-bcache-multisource-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
{
        echo '.text'
        echo '.globl bcache_fetch'
        sed -n '/^bcache_fetch:/,/^; void bcache_store/p' "$source_file" |
                sed '$d'
} > "$work/cache.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 1000000 --timeout 15 \
        --workdir "$work/run" --name daimos-bcache-multisource-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-bcache-multisource-v1.s" \
        "$work/cache.s" >/dev/null
printf '%s\n' 'bcache-multisource: PASS (one-word key separates cache sources)'
