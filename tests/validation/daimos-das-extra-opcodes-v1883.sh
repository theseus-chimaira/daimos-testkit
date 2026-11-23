#!/bin/sh
# Verify compressed extended opcode keys against the frozen oracle.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${DAS_ROOT:?DAS_ROOT must name DAS source}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
binary=$(mktemp "$TMPDIR/das-extra-opcodes-v1883.XXXXXXXX")
trap 'rm -f "$binary"' EXIT HUP INT TERM
"${CC:-cc}" -std=c89 -O2 -I"$DAS_ROOT" \
    "$here/daimos-das-extra-opcodes-v1883.c" -o "$binary"
"$binary" "$here/daimos-das-extra-opcodes-v1883.tsv"
