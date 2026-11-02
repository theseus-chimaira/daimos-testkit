#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tty-session-release-v967.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ printf '.text\n.globl proc_tty_release_session\n';
  sed -n '/^proc_tty_release_session:$/,/^; Remove only trailing FREE/p' "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d';
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode step --start 1000 --step-limit 100000 --timeout 20 \
 --workdir "$work/run" --name tty-session-release-v967 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
 "$self/daimos-tty-session-release-v967.s" > "$work/log" 2>&1 || {
 tail -35 "$work/log" >&2
 exit 1
 }
echo 'v967: TTY MM refusal retains session; successful retry releases PASS'
