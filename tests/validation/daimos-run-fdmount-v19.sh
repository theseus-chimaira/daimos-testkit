#!/bin/sh
# Native RUN descriptor-map loop, as assembled in production proc_run.s.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-run-fdmount-v19.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source="$DAIMOS_REPO/system/kernel/proc/proc_run.s"
{
    printf '%s\n' '.text' '.globl proc_run_map_loop' \
        '.equ PROC_FILE_TABLE_OFFSET,026' '.equ PROC_FDMOUNT_OFFSET,067'
    sed -n '/^proc_run_map_loop:/,/^proc_run_map_done:/p' "$source" | sed '$d'
    printf '%s\n' 'proc_run_map_done:' 'setz 1,' 'popj 17,' \
        'proc_run_fdmap_bad:' 'seto 1,' 'popj 17,'
} > "$work/run-leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-run-fdmount-v19 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-run-fdmount-v19.s" "$work/run-leaf.s" >/dev/null
echo 'run-fdmount-v19: PASS (RUN copies two-bit mount extension with descriptor map)'
