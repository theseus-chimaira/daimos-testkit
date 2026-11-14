#!/bin/sh
# P1-C physical unretried LOGSTORE orphan and cold-boot KINIT recovery.
# Two full 128K PDP-6 cold boots reuse the same physical 8 MiB drum.
# The only changed service is a disposable copy of the LOGSTORE MRES.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-orphan-v1578.XXXXXX")
if [ "${V1578_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1578 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"

# The v1577 source injection is retained, but v1578 injects only the
# first boot's unique code: second boot must exercise native LOGSTORE
# recovery and an unmodified commit, not a second synthetic failure.
python3 "$self/daimos-p1c-logstore-torn-v1577.py" \
    "$DAIMOS_REPO/system/kernel/storage/logstore_runtime.s" \
    "$work/source/system/kernel/storage/logstore_runtime.s"
python3 - "$work/source/system/kernel/storage/logstore_runtime.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
old = ('daimos_test_logstore_other_v1577:\n'
       '        caie    0,0157602\n'
       '        jrst    logstore_write          ; unrelated system log event\n')
new = ('daimos_test_logstore_other_v1577:\n'
       '        jrst    logstore_write          ; all except first-boot orphan\n')
assert s.count(old) == 1, 'v1578: source-linked v1577 injector changed'
p.write_text(s.replace(old, new, 1))
print('PASS v1578: only first-boot event can receive injected I/O error')
PY

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1578_P1C_ORPHAN=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_ORPHAN_V1578=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1578: full real PDP-6 boot, leave invalid LOGSTORE sector across HALT'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1578.log" 2>&1 || {
    tail -105 "$work/fullguest-v1578.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/logstore-mres.map"
grep -q '^daimos_test_logstore_faults_v1577[[:space:]]' \
    "$boot/logstore-mres.map"
test -s "$work/persistent/orphan-physical-v1578.txt"
grep -Fq 'PASS v1578: exact uncommitted LSREC1' \
    "$work/persistent/orphan-physical-v1578.txt"
first="$work/persistent/boot-1/simh.log"
second="$work/persistent/boot-2/simh.log"
grep -Fq 'P1C-LOGSTORE-TORN-REFUSED' "$first"
grep -Fq 'P1C-ORPHAN-LEFT-UNCOMMITTED' "$first"
grep -Fq 'XIP-SNAPSHOT-WRITTEN' "$first"
if grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' "$first"; then
    echo 'FAIL v1578: invalid first-boot event was retried' >&2
    exit 1
fi
grep -Fq 'P1C-ORPHAN-IGNORED' "$second"
grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' "$second"
grep -Fq 'XIP-SNAPSHOT-RESTORED' "$second"

python3 "$self/daimos-p1c-orphan-recovery-v1578.py" \
    "$boot/drum/dsk0.dsk" "$work/persistent/orphan-physical-v1578.txt" \
    "$work/recovered-physical-v1578.txt"
python3 "$self/daimos-p1c-orphan-mutants-v1578.py" \
    "$boot/drum/dsk0.dsk" "$work/persistent/orphan-physical-v1578.txt" \
    "$self/daimos-p1c-orphan-recovery-v1578.py" "$work/mutants"

"$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
    > "$work/auxstore-final.inspect"
cmp "$work/persistent/auxstore-v1477.inspect" \
    "$work/auxstore-final.inspect"
echo 'PASS v1578: real uncommitted LOGSTORE record persisted through HALT'
echo 'PASS v1578: KINIT ignored orphan on fresh boot; new committed record accepted'
echo 'PASS v1578: MEMFS data/XIP restored and physical AUXSTORE geometry unchanged'
echo 'P1-C remains open: concurrent physical swap/commit and natural hardware fault'
