#!/bin/sh
# Native PDP-6 EXEC post-commit fatal: FILE close before irreversible EXIT.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-exec-fatal-close-v878.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl native_sys_exec\n'
    sed -n '/^native_sys_exec:$/,/^; Read one raw 128-word DECtape block/p' \
        "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name exec-fatal-close-v878 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-exec-fatal-close-v878.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v878: native post-commit EXEC fatal FILE-close and precommit behavior PASS'
