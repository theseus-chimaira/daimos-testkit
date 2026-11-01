#!/bin/sh
# v897: PDP-6 PROCCTL TTY ownership cannot cross an unreleased line.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
case "${DAIMOS_V897_NEGATIVE:-0}" in
    0|1) ;;
    *) echo 'v897: invalid negative control selection' >&2; exit 2 ;;
esac
work=$(mktemp -d "$TMPDIR/daimos-tty-ownership-retry-v897.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_file="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
expected_exit=0
if [ "${DAIMOS_V897_NEGATIVE:-0}" = 1 ]; then
    git -C "$DAIMOS_REPO" show \
        8cfe0fa:system/kernel/proc/proc_pdp6.s > "$work/old.s"
    source_file="$work/old.s"
    expected_exit=1
fi
{
    printf '.text\n.globl proc_control_tty_attach\n.globl proc_control_tty_detach\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n'
    sed -n '/^proc_control_tty_attach:$/,/^; Decode and validate the caller/p' \
        "$source_file" | sed '$d'
    sed -n '/^proc_control_tty_detach:$/,/^; AC1=session, AC2=packed TTY state/p' \
        "$source_file" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 130000 --timeout 25 \
    --workdir "$work/run" --name tty-ownership-v897 --expect __test_exit="$expected_exit" \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-tty-ownership-retry-v897.s" > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
if [ "$expected_exit" = 1 ]; then
    echo 'v897: pre-v897 negative control FAILS at unsafe pinned-line ATTACH as expected'
else
    echo 'v897: failed TTY detach retains old session; new attach refuses pinned line; release and retry PASS'
fi
