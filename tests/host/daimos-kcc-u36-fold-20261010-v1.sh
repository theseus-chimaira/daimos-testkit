#!/bin/sh
# Host cross-KCC must fold unsigned operations at the 36-bit target width.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
w=$(mktemp -d "$TMPDIR/daimos-kcc-u36-fold-20261010-v1.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
make -C "$KCC_REPO" PLATFORM=cross -j2 \
    HOST_BUILD_DIR="$w/host" KCC="$w/host/kcc" "$w/host/kcc" \
    > "$w/build.log" 2>&1
cat > "$w/fold.c" <<'C99'
unsigned u36_half = ((unsigned)(~0) >> 1);
unsigned u36_quarter = ((unsigned)(~0) >> 2);
C99
(cd "$w" && "$w/host/kcc" -S -Pgnu99 -x=pdp6 -m=gas fold.c \
    > "$w/compile.log" 2>&1)
awk '/^u36_half:/ {getline; if ($0 !~ /[.]word 0377777777777$/) exit 1; found=1} END {if (!found) exit 1}' "$w/fold.s"
awk '/^u36_quarter:/ {getline; if ($0 !~ /[.]word 0177777777777$/) exit 1; found=1} END {if (!found) exit 1}' "$w/fold.s"
cat > "$w/unsized.c" <<'C99'
int unsized_array[] = {[0] = 3, [7] = 11, [63] = 19};
int unsized_braces[] = {5, 6, 7};
C99
(cd "$w" && "$w/host/kcc" -S -Pgnu99 -x=pdp6 -m=gas unsized.c \
    > "$w/unsized.log" 2>&1)
grep -Fq 'unsized_array:' "$w/unsized.s"
grep -Fq 'unsized_braces:' "$w/unsized.s"
if grep -q 'Array designator index exceeds array bounds' "$w/unsized.log"; then
    echo 'FAIL: unsized designated initializer rejected' >&2
    exit 1
fi
echo 'PASS: 36-bit unsigned shift folding and unsized array initializers'
