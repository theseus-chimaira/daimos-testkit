#!/bin/sh
# Check phase-1-only opcode set against an independent immutable oracle.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${DAS_ROOT:?DAS_ROOT must name the DAS checkout}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
binary=$(mktemp "$TMPDIR/das-phase1-opcodes-v1882.XXXXXXXX")
trap 'rm -f "$binary"' EXIT HUP INT TERM
"${CC:-cc}" -std=c89 -O2 -I"$DAS_ROOT" \
    "$here/daimos-das-phase1-opcodes-v1882.c" -o "$binary"
"$binary" "$here/daimos-das-opcode-map-v1877.tsv"
