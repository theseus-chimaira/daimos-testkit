#!/bin/sh
# Verify that a two-dimensional 9-bit char store retains both indexes.
set -eu
: "${PDP10_PREFIX:?} ${TMPDIR:?}"

cc=${PDP10_GCC:-$PDP10_PREFIX/bin/pdp10-dec-none-gcc}
cc_b=${PDP10_GCC_B:-}
das=$PDP10_PREFIX/bin/das
source=$(dirname "$0")/pdp10-gcc-multidim-char-20261012-v1.c
work=$TMPDIR/pdp10-gcc-multidim-char-20261012-v1-$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

for level in 0 1 2; do
        if [ -n "$cc_b" ]; then
                "$cc" -B"$cc_b" -O"$level" -S "$source" -o "$work/out.s"
        else
                "$cc" -O"$level" -S "$source" -o "$work/out.s"
        fi
        "$das" -F -C -O "$work/out.dobj" "$work/out.s"

        # Check within set_array, not in the separately compiled row_array.
        sed -n '/^set_array:/,/^get_array:/p' "$work/out.s" > "$work/first.s"
        grep -Eq 'muli[[:space:]]+[^,]+,0147' "$work/first.s" || {
                echo "PDP-10 GCC -O$level lost the 103-byte row stride" >&2
                exit 1
        }
        echo "PASS -O$level: multidimensional row index preserved"
done
