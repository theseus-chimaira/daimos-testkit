#!/bin/sh
# Native source-linked ownership, disabled-allocation release, duplicate-free.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-free-v1393.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
        printf '.text\n.globl backstore_free\n.globl backstore_verify_allocated_v795\n'
        sed -n '/^backstore_verify_allocated_v795:$/,/^; int backstore_extend(first,old_blocks,new_blocks)/p' \
            "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'
        sed -n '/^backstore_free:$/,/^        \.bss/p' \
            "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'
} > "$work/leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 200000 --timeout 20 \
    --workdir "$work/run" --name backstore-free-v1393 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/leaves.s" "$self/daimos-backstore-free-ownership-v1393.s" \
    > "$work/log" 2>&1 || { tail -35 "$work/log" >&2; exit 1; }
echo 'PASS v1393: native BACKSTORE ownership and disabled-release protection'
