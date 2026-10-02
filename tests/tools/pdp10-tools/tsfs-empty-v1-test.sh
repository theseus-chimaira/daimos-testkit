#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
work=$TMPDIR/tsfs-empty-v1-$$
trap 'rm -rf "$work"' 0 1 2 3 15
mkdir -p "$work"

./mktsfs -n 8 -i 1:2 -g 7 -o "$work/set"
./tsfscheck "$work/set0.dta" "$work/set1.dta" "$work/set2.dta" \
        "$work/set3.dta" "$work/set4.dta" "$work/set5.dta" \
        "$work/set6.dta" "$work/set7.dta" >/dev/null
# Physical argument order is independent of logical member index.
./tsfscheck "$work/set7.dta" "$work/set3.dta" "$work/set0.dta" \
        "$work/set6.dta" "$work/set2.dta" "$work/set5.dta" \
        "$work/set1.dta" "$work/set4.dta" >/dev/null

if ./tsfscheck "$work/set0.dta" "$work/set1.dta" "$work/set2.dta" \
        "$work/set3.dta" "$work/set4.dta" "$work/set5.dta" \
        "$work/set6.dta" >/dev/null 2>&1; then
        echo 'tsfs-empty-v1: incomplete set accepted' >&2
        exit 1
fi

cp "$work/set1.dta" "$work/dup.dta"
if ./tsfscheck "$work/set0.dta" "$work/dup.dta" "$work/set1.dta" \
        "$work/set2.dta" "$work/set3.dta" "$work/set4.dta" \
        "$work/set5.dta" "$work/set6.dta" "$work/set7.dta" >/dev/null 2>&1; then
        echo 'tsfs-empty-v1: duplicate member accepted' >&2
        exit 1
fi

# One damaged descriptor replica must be recoverable from the other copy.
primary=$((128 * 8 + 16))
printf '\001' | dd of="$work/set2.dta" bs=1 seek="$primary" conv=notrunc 2>/dev/null
./tsfscheck "$work/set0.dta" "$work/set1.dta" "$work/set2.dta" \
        "$work/set3.dta" "$work/set4.dta" "$work/set5.dta" \
        "$work/set6.dta" "$work/set7.dta" >/dev/null

# Damage the same word in the backup descriptor as well; now the member fails.
backup=$((2 * 128 * 8 + 16))
printf '\001' | dd of="$work/set2.dta" bs=1 seek="$backup" conv=notrunc 2>/dev/null
if ./tsfscheck "$work/set0.dta" "$work/set1.dta" "$work/set2.dta" \
        "$work/set3.dta" "$work/set4.dta" "$work/set5.dta" \
        "$work/set6.dta" "$work/set7.dta" >/dev/null 2>&1; then
        echo 'tsfs-empty-v1: double descriptor corruption accepted' >&2
        exit 1
fi

printf '%s\n' 'tsfs-empty-v1 PASS (eight members)'
