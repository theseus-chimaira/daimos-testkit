#!/bin/sh
# P1-C v1576: full PDP-6 128K two cold boots, same MEMFS and LOGSTORE
# AUXSTORE backing, actual LOGCTL commit-last append, physical readback,
# and independent second-boot recovery of the original LOGSTORE record.
# This is a mixed-storage slice, NOT proof of simultaneous process swap.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-logstore-snapshot-v1576.XXXXXX")
if [ "${V1576_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1576 evidence: $work"
fi

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1'

echo 'v1576: build full current-source 128K PDP-6 with persistent MEMFS and LOGSTORE'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1576.log" 2>&1 || {
    tail -100 "$work/fullguest-v1576.log" >&2
    exit 1
}

for n in 1 2; do
    log="$work/persistent/boot-$n/simh.log"
    test -s "$log"
    grep -q '^LOGSTR[[:space:]]*LOADED' "$log"
    grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' "$log"
    grep -Fq 'XIP-SNAPSHOT-' "$log"
    if [ "$n" = 2 ]; then
        grep -Fq 'P1C-LOGSTORE-PREVIOUS-BOOT' "$log"
        grep -Fq 'XIP-SNAPSHOT-RESTORED' "$log"
    fi
done

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/drum/dsk0.dsk"
"$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
    > "$work/auxstore-final.inspect"
cmp "$work/persistent/auxstore-v1477.inspect" \
    "$work/auxstore-final.inspect"
echo 'PASS v1576: real LOGSTORE append, direct readback, boot-two record restore'
echo 'PASS v1576: physical committed MEMFS XIP snapshot and unchanged AUXSTORE descriptor'
echo 'P1-C remains open: no concurrent swap-in/commit or in-flight device fault was tested'
