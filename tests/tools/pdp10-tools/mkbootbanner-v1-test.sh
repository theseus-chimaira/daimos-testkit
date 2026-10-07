#!/bin/sh
set -eu
: "${TMPDIR:?TMPDIR must be set}"
out="$TMPDIR/mkbootbanner-v1-$$.s"
trap 'rm -f "$out"' EXIT HUP INT TERM
./mkbootbanner -v 0.1 -o "$out"
grep -q '^minit_dpy_banner_words:$' "$out"
grep -q '^        \.word 0020000020240$' "$out"
grep -q '^        \.word 0201000000000$' "$out" || grep -q '^        \.word 201000000000$' "$out"
grep -q '^        \.word 0566140404037$' "$out" || grep -q '^        \.word 566140404037$' "$out"
grep -q '^minit_wcnsls_banner_glyphs:$' "$out"
grep -q '^        \.word 0214306142504$' "$out"
grep -q '^        \.word 0000000000306$' "$out"
echo 'mkbootbanner-v1: PASS'
