#!/bin/sh
# Check the one-word DAS directive table against an independent full list.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${DAS_ROOT:?DAS_ROOT must name the DAS source tree}"
binary=$(mktemp "$TMPDIR/das-packed-tokens-v1871.XXXXXXXX")
trap 'rm -f "$binary"' EXIT HUP INT TERM
"${CC:-cc}" -std=c89 -O2 -I"$DAS_ROOT" \
    "$here/daimos-das-packed-tokens-v1871.c" -o "$binary"
"$binary"
