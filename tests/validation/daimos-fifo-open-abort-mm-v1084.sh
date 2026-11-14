#!/bin/sh
# v1084: interruptible FIFO OPEN with actual pinned PDP-6 MM teardown.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fifo-open-abort-mm-v1084.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_file="$DAIMOS_REPO/system/kernel/ipc/pipe.s"
if [ "${DAIMOS_V1084_NEGATIVE:-0}" = 1 ]; then
    git -C "$DAIMOS_REPO" show \
        fdbae2a2:system/kernel/ipc/pipe.s > "$work/old.s"
    source_file="$work/old.s"
fi
{
    printf '.text\n.globl pipe_fifo_open\n.globl pipe_fifo_find\n'
    printf '.globl pipe_fifo_unlink_object\n.globl pipe_close_ref\n'
    printf '.globl file_open\n.globl file_new_fd\n.globl file_close_entry_v865\n'
    sed -n '/^file_open:$/,/^; kword_t vfs_current_owner/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    sed -n '/^file_close_entry_v865:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    sed -n '/^file_new_fd:$/,/^; kword_t file_seek(int fd/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    # The post-v1531 FILE close slice includes administrative DTFS code
    # that references the ordinary descriptor lookup, even though FIFO
    # OPEN does not execute it. Link the unchanged real lookup leaf.
    sed -n '/^file_find:$/,/^; int file_new_fd(vnode_t node/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    sed -n '/^pipe_fifo_find:$/,/^; Remove AC1 object/p' \
        "$source_file" | sed '$d'
    sed -n '/^pipe_fifo_unlink_object:$/,/^; kword_t pipe_create/p' \
        "$source_file" | sed '$d'
    sed -n '/^pipe_fifo_open:$/,/^[[:space:]]*\.globl  pipe_fifo_detach$/p' \
        "$source_file" | sed '$d'
    sed -n '/^pipe_close_ref:$/,/^[[:space:]]*\.bss$/p' \
        "$source_file" | sed '$d'
    printf '.globl mm_unpin\n.equ MM_PIN_FIELD,03770000000\n'
    printf '.equ MM_PIN_ONE,010000000\n'
    sed -n '/^mm_delete:$/,/^; int mm_extent_insert/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_free:$/,/^; int mm_process_transfer_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/leaf.s"
expect=0
if [ "${DAIMOS_V1084_NEGATIVE:-0}" = 1 ]; then
    expect=1
fi
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 25 \
    --workdir "$work/run" --name fifo-open-abort-mm-v1084 \
    --expect __test_exit="$expect" \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fifo-open-abort-mm-v1084.s" > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2
        exit 1
    }
if [ "$expect" = 0 ]; then
    echo 'v1084: pinned OPEN-rollback refusal preserves FD owner, unpin/close succeeds PASS'
else
    echo 'v1084: pre-v1084 interrupted OPEN loses MM retry owner; negative FAIL expected'
fi
