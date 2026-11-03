#!/bin/sh
# Native PDP-6 actual NEWSESSION/TTY release, plus pre-fix negative control.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-newsession-tty-rollback-v1082.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_file="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
expect=0
if [ "${DAIMOS_V1082_NEGATIVE:-0}" = 1 ]; then
    git -C "$DAIMOS_REPO" show \
        0a518856:system/kernel/proc/proc_pdp6.s > "$work/pre-v1082.s"
    source_file="$work/pre-v1082.s"
    expect=1
fi
if [ "$expect" = 1 ]; then
    first=3
    resets=1
    scans=1
else
    first=777777777777
    resets=2
    scans=3
fi
{
    printf '.text\n.globl proc_control_newsession\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n'
    sed -n '/^proc_control_newsession:$/,/^proc_control_newdomain:$/p' \
        "$source_file" | sed '$d'
    sed -n '/^proc_tty_release_session:$/,/^; Remove only trailing FREE/p' \
        "$source_file" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 20 \
    --workdir "$work/run" --name newsession-tty-rollback-v1082 \
    --expect __test_exit="$expect" \
    --expect __first_return_v1082="$first" \
    --expect __reset_calls="$resets" \
    --expect __scan_error=0 \
    --expect __scan_calls="$scans" \
    --expect __seen_session=5 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-newsession-tty-rollback-v1082.s" > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2
        exit 1
    }
if [ "$expect" = 1 ]; then
    echo 'v1082: original NEWSESSION publishes before MM release; negative FAIL expected'
else
    echo 'v1082: MM refusal rollback, successful transition and peer ownership PASS'
fi
