#!/bin/sh
set -eu

: "${DAIMOS_REPO:?set DAIMOS_REPO to the DAIMOS checkout}"

io="$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"
control="$DAIMOS_REPO/system/kernel/drivers/dpy_text_control_pdp6.s"

# Both the retained store and the BLKO refresh state machine must agree on
# 46 decimal rows (056 octal).  This catches the 42-row refresh regression.
grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_TEXT_ROWS,056$' "$io"
grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_TEXT_ROWS,056$' "$control"

# Refresh-only states must live above the valid row numbers 0..055 octal.
grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_REFRESH_BANNER,056$' "$io"
grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_REFRESH_ONESHOT,057$' "$io"
grep -Eq '^[[:space:]]*\.equ[[:space:]]+DPY_REFRESH_TRAILER,060$' "$io"

echo 'dpy-46row-refresh: PASS'
