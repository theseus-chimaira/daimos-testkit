#!/bin/sh
set -eu

: "$DAIMOS_REPO"
: "$TMPDIR"

control="$DAIMOS_REPO/system/kernel/drivers/dpy_text_control_pdp6.s"
io="$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"
commands="$DAIMOS_REPO/userland/exec/commands.c"

grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_TEXT_ROWS,056$' "$control"
grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_TEXT_ALLOC_WORDS,02410$' "$control"
grep -Eq '^[[:space:]]*movei[[:space:]]+1,1\(5\)$' "$control"

if grep -Eq '^[[:space:]]*aoj[[:space:]]+1,5$' "$control"; then
        echo 'dpy-scroll-clear: stale ring-top AOJ regression present' >&2
        exit 1
fi

grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_TEXT_ROWS,056$' "$io"
grep -Eq '^[[:space:]]*\.word[[:space:]]+0201762060000$' "$io"
grep -Eq 'return u_putc\(io->out_fd, 014\) != 0;' "$commands"

echo 'dpy-scroll-clear: PASS'
