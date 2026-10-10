#!/bin/sh
# Verify that a hosted KCC emits PDP-6's 35-bit positive bound.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
w=$(mktemp -d "$TMPDIR/daimos-kcc-array-bound36-20261010-v1.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
cd "$w"
"${PDP10_KCC:-/usr/local/bin/kcc}" -S -P=stdc+kcc \
    -DHOST_DAIMOS=1 -DHOST_UNIX=0 -I"$KCC_REPO/self/include/" -H"$KCC_REPO/self/include/" \
    -x=pdp6 -m=gas "$KCC_REPO/ccdecl.c" > "$w/compiler.log" 2>&1
# The unsized-array bound is a target INT, never the host unsigned width.
grep -Fq 'move' "$w/ccdecl.s"
grep -Fq '[0377777777777]' "$w/ccdecl.s"
if grep -Fq '[0777777777777777777777]' "$w/ccdecl.s"; then
    echo 'FAIL: host-width all-ones bound emitted' >&2
    exit 1
fi
printf '%s\n' 'PASS: exact PDP-6 35-bit maximum array bound'
