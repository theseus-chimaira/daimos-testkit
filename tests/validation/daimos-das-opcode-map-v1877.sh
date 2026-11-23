#!/bin/sh
# Check the current source against independently frozen v1876 opcodes.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${DAS_ROOT:?DAS_ROOT must name the DAS checkout}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
binary=$(mktemp "$TMPDIR/das-opcode-map-v1877.XXXXXXXX")
trap 'rm -f "$binary"' EXIT HUP INT TERM
"${CC:-cc}" -std=c89 -O2 -I"$DAS_ROOT" \
    "$here/daimos-das-opcode-map-v1877.c" -o "$binary"
"$binary" "$here/daimos-das-opcode-map-v1877.tsv"
