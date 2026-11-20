#!/bin/sh
# Source-linked native RUN fdmap, PIPE refs, FILE final-close ownership.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k02-run-pipe-lifetime-v1722.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
    printf '%s\n' '.text' '.globl proc_run_map_loop' \
        '.equ PROC_FILE_TABLE_OFFSET,026'
    sed -n '/^proc_run_map_loop:/,/^proc_run_map_done:/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_run.s" | sed '$d'
    printf '%s\n' 'proc_run_map_done:' 'setz 1,' 'popj 17,' \
        'proc_run_fdmap_bad:' 'seto 1,' 'popj 17,'

    printf '%s\n' '.globl pipe_add_ref' '.globl pipe_add_refs'
    sed -n '/^pipe_add_ref:/,/^        \.globl  pipe_close_ref/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
    printf '%s\n' '.globl pipe_close_ref' '.globl pipe_fifo_unlink_object'
    sed -n '/^pipe_fifo_unlink_object:/,/^; kword_t pipe_create/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
    sed -n '/^pipe_close_ref:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'

    printf '%s\n' '.globl file_close_entry_v865' \
        '.globl file_close_all_at_v865'
    sed -n '/^file_close_entry_v865:$/,/^; Root explicitly abandons/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    sed -n '/^file_close_all:$/,/^; Shared bulk-word/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
} > "$work/production.s"

python3 - "$work/production.s" "$work/unsafe-no-refs.s" \
    "$work/unsafe-fd-clear.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = 'pipe_add_refs:\n        jumpe   1,pipe_add_refs_empty\n'
assert source.count(old) == 1
Path(sys.argv[2]).write_text(source.replace(
    old, 'pipe_add_refs:\n        popj    17,\n', 1))
old = 'file_close_finish:\n        jumpn   1,file_close_done\n'
assert source.count(old) == 1
Path(sys.argv[3]).write_text(source.replace(
    old, 'file_close_finish:\n        jrst    file_close_publish_v1722\n'
         'file_close_publish_v1722:\n', 1))
PY

run_case()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 25 \
        --workdir "$work/run-$name" --name "k02-run-pipe-v1722-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k02-run-pipe-lifetime-v1722.s" "$source" \
        > "$work/$name.log" 2>&1
}
run_case production "$work/production.s" || {
    tail -55 "$work/production.log" >&2
    exit 1
}
for name in unsafe-no-refs unsafe-fd-clear; do
    if run_case "$name" "$work/$name.s"; then
        echo "v1722: $name unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit: got' "$work/$name.log" || {
        tail -50 "$work/$name.log" >&2
        exit 1
    }
done
echo 'K02 v1722: rejected RUN no-ref, duplicate PIPE inheritance, failed TSFS sync + exact FILE witness/retry, final PIPE MM_BUSY + witness/retry, two mutants PASS'
