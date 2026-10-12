#!/bin/sh
# Strict host C99 bounded-undo write-order experiment.
set -eu
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-undo-20261012-v1.XXXXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cc=${HOST_CC:-cc}
"$cc" -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
    tests/host/daimos-d6fs-undo-cuts-20261012-v1.c \
    -o "$work/undo"
"$work/undo"
