#!/bin/sh
# Exact native PDP-6 pipe_add_ref/pipe_add_refs extracted from pipe.s.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-pipe-directmount-20261026-v417.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source="$DAIMOS_REPO/system/kernel/ipc/pipe.s"
{
    printf '%s\n' '.text' '.globl pipe_add_ref' '.globl pipe_add_refs'
    sed -n '/^pipe_add_ref:/,/^        \.globl  pipe_close_ref/p' "$source" | sed '$d'
} > "$work/pipe-leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 15 \
    --workdir "$work/run" --name daimos-pipe-directmount-20261026-v417 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-pipe-directmount-20261026-v417.s" "$work/pipe-leaves.s" >/dev/null
echo 'pipe-directmount-v417: PASS (TSFS mount 8 cannot acquire PIPE references)'
