#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
work="$TMPDIR/daimos-auxstore-v492-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
awk '/^auxstore_boot_discover\(void\)/{printing=1; print "int"} printing {print} printing && /^\/\*\* Publish AUXSTORE/{exit}' \
    "$DAIMOS_REPO/system/kernel/storage/auxstore_boot.c" | sed '$d' \
    > "$work/auxstore-discovery-under-test.c"
cp "$(dirname "$0")/daimos-auxstore-choice-v492.c" "$work/test.c"
${CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -I"$work" \
    "$work/test.c" -o "$work/test"
"$work/test"
