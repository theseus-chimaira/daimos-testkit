#!/bin/sh
# Reject KCORE boundary markers preceding a resident backing-state word.
# The MM extent table begins at __kcore_low_end; overlap corrupts the
# authoritative BACKSTORE bitmap and causes late KINIT allocation failure.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
    permanent-size BOOT_PROFILE=lowmem ROOT=disk COMPILER=gcc >/dev/null
map="$DAIMOS_REPO/build/system/boot/pdp6/kcore.map"
test -s "$map"
sym() {
    awk -v s="$1" '$1 == s {print $2; n++} END {if (n != 1) exit 1}' "$map"
}
end=$(sym __kcore_low_end)
extents=$(sym mm_extents)
test "$end" = "$extents" || {
    echo 'KCORE end no longer equals MM extent start' >&2
    exit 1
}
end_dec=$((0$end))
for name in backstore_bitmap backstore_blocks backstore_blocks_used backstore_enabled; do
    addr=$(sym "$name")
    addr_dec=$((0$addr))
    if test "$addr_dec" -ge "$end_dec"; then
        echo "KCORE/MM boundary overlaps $name ($addr >= $end)" >&2
        exit 1
    fi
done
printf '%s\n' "daimos-kcore-end-boundary-v484: PASS (BACKSTORE state ends below KCORE/MM boundary $end)"
