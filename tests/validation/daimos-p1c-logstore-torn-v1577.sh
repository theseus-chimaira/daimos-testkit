#!/bin/sh
# Full 128K PDP-6 two-cold-boot LOGSTORE torn commit and MEMFS XIP
# persistence. Source-linked disposable MRES, original production KCORE.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-logstore-torn-v1577.XXXXXX")
if [ "${V1577_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1577 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
# The production kernel's KINIT dependency graph requires the parent
# release marker and the real standalone source tree in a copied root.
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
python3 "$self/daimos-p1c-logstore-torn-v1577.py" \
    "$DAIMOS_REPO/system/kernel/storage/logstore_runtime.s" \
    "$work/source/system/kernel/storage/logstore_runtime.s"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_LOGFAULT_V1577=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"
echo 'v1577: two real PDP-6 boots with physically uncommitted LSREC1 and retry'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1577.log" 2>&1 || {
    tail -100 "$work/fullguest-v1577.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
grep -q '^daimos_test_logstore_faults_v1577[[:space:]]' \
    "$boot/logstore-mres.map"
grep -q '^daimos_test_logstore_physical_v1577[[:space:]]' \
    "$boot/logstore-mres.map"
for n in 1 2; do
    log="$work/persistent/boot-$n/simh.log"
    test -s "$log"
    grep -Fq 'P1C-LOGSTORE-TORN-REFUSED' "$log"
    grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' "$log"
    grep -Fq 'XIP-SNAPSHOT-' "$log"
    if [ "$n" = 2 ]; then
        grep -Fq 'P1C-LOGSTORE-PREVIOUS-BOOT' "$log"
        grep -Fq 'XIP-SNAPSHOT-RESTORED' "$log"
    fi
done

"$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
    > "$work/auxstore-final.inspect"
cmp "$work/persistent/auxstore-v1477.inspect" \
    "$work/auxstore-final.inspect"
echo 'PASS v1577: failed physical uncommitted LOGSTORE record kept original cursor'
echo 'PASS v1577: real same-slot retry, new boot old record, MEMFS snapshot restored'
echo 'P1-C still OPEN: natural controller loss and concurrent swap/snapshot remain'
