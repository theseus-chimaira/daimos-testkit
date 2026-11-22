#!/bin/sh
# KCC-generated native MAKE prolog and object size comparison, no fixtures
# substituted for the production DAIMOS source.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the DAIMOS checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/cat-make-frame-v1814.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

# The last unchanged baseline before this isolated feature promotion.
git -C "$DAIMOS_REPO" show \
    dbdc403f:userland/exec/make.c >"$work/make-before-v1814.c"
set --
for dir in boot core drivers fs mm modules proc storage; do
    set -- "$@" "-I$DAIMOS_REPO/system/kernel/$dir"
done
set -- "$@" "-I$DAIMOS_REPO/userland/libc" \
    "-I$DAIMOS_REPO/userland/exec" "-I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas "$@" \
    -S "$work/make-before-v1814.c" -o "$work/before.s"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas "$@" \
    -S "$DAIMOS_REPO/userland/exec/make.c" -o "$work/current.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/before.dobj" "$work/before.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/current.dobj" "$work/current.s"
python3 "$here/check-make-frame-v1814.py" "$work/before.s" \
    "$work/current.s" "$work/before.dobj" "$work/current.dobj" \
    "$PDP10_PREFIX/bin/pdp10-objdump"
