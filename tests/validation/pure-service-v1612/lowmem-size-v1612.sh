#!/bin/sh
# Pin the GCC low-memory PURE module footprint independently of KCC.
# Build only the optional MRES and fixed KCORE; do not claim physical
# guest placement or full no-AUXST1 runtime acceptance from this check.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/pure-lowmem-v1612.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" = 1 ]; then echo "v1612 GCC work: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
boot="$DAIMOS_REPO/system/boot/pdp6"

if ! make -s -C "$boot" BUILD="$work" ROOT=tape \
    BOOT_PROFILE=lowmem COMPILER=gcc \
    DAIMOS_PURE_MRES_ENABLED=1 \
    "$work/purev1612-mres.dobj" >"$work/build.log" 2>&1; then
    tail -60 "$work/build.log" >&2
    exit 1
fi
test -s "$work/pure-mres-v1612.fold"
grep -q '^FOLD[[:space:]]' "$work/pure-mres-v1612.fold"
section=$("$PDP10_PREFIX/bin/pdp10-objdump" -h \
    "$work/purev1612-mres.dobj" | grep '^mres:')
echo "$section" | grep -q 'resident=1758' || {
    echo "FAIL v1612: GCC PURE MRES is not 1758 words: $section" >&2
    exit 1
}
grep -q '^__kcore_low_end[[:space:]]*024254' "$work/kcore.map" || {
    echo 'FAIL v1612: GCC fixed KCORE changed' >&2
    exit 1
}
echo 'PASS v1612 GCC lowmem: folded PURE 1758 words, KCORE low end 024254'
