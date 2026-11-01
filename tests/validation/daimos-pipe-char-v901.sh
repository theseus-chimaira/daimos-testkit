#!/bin/sh
# v901 native PDP-6: character PIPE and FIFO stream dispatch is real word I/O.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
case "${DAIMOS_V901_NEGATIVE:-0}" in
    0|1) ;;
    *) echo 'v901: invalid negative control choice' >&2; exit 2 ;;
esac
work=$(mktemp -d "$TMPDIR/daimos-pipe-char-v901.XXXXXX")
source_file="$DAIMOS_REPO/system/kernel/fs/vfs.s"
expected_exit=0
if [ "${DAIMOS_V901_NEGATIVE:-0}" = 1 ]; then
    git -C "$DAIMOS_REPO" show a0ffe39:system/kernel/fs/vfs.s > "$work/pre-v901.s"
    source_file="$work/pre-v901.s"
    expected_exit=1
fi
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl vfs_readchar\n.globl vfs_writechar\n'
    sed -n '/^vfs_readchar:$/,/^; Compact 36-bit policy/p' \
        "$source_file" | sed '$d'
    sed -n '/^pipe_read_words:$/,/^; int pipe_write_words/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
    sed -n '/^pipe_write_words:$/,/^[[:space:]]*\.globl[[:space:]]*pipe_add_ref/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 160000 --timeout 25 \
    --workdir "$work/run" --name pipe-char-v901 --expect __test_exit="$expected_exit" \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-pipe-char-v901.s" > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2; exit 1
    }
if [ "$expected_exit" = 1 ]; then
    echo 'v901: old VFS character path rejects PIPE WRITECHAR, negative control PASS'
else
    echo 'v901: native PIPE WRITECHAR/READCHAR queue, EOF, broken pipe, unchanged device dispatch PASS'
fi
