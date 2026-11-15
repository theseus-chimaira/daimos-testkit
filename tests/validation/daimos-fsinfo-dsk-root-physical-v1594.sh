#!/bin/sh
# Full 128K PDP-6 real four-member DSK270-root FSINFO inventory.
# Uses the unmodified KINIT/FSINFO handler and real root media.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fsinfo-dsk-root-v1594.XXXXXX")
if [ "${V1594_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1594 evidence: $work"
fi
export XIP_V1469_WORK="$work/guest" XIP_V1469_KEEP=1
export XIP_V1470_BOOT_CORE_WORDS=0400000
export XIP_V1470_SIMH_CPU_KWORDS=128
export XIP_V1477_TEST_CFLAGS='-DXIP_P1D_DSK_FSINFO_V1594=1'
export XIP_V1594_P1D_DSK_FSINFO=1
# Each run owns independent listener ports, including when another physical
# PDP-6 snapshot is in progress. The default 1101/1201 collide across guests.
port_offset_v1594=$(( $$ % 10000 ))
export SIMH_DCS0_PORT=$(( 23000 + port_offset_v1594 ))
export SIMH_GE0_PORT=$(( 43000 + port_offset_v1594 ))
echo 'v1594: original full PDP-6 DSK root and dynamic FSINFO capacity'
sh "$self/daimos-xip-launch-v1469.sh" > "$work/fullguest-v1594.log" 2>&1 || {
    tail -115 "$work/fullguest-v1594.log" >&2
    exit 1
}
grep -Fq 'P1D-D6FS-DSK-CAPACITY6-V1594' \
    "$work/guest/run/simh.log" || {
    echo 'v1594: full guest did not publish physical FSINFO witness' >&2
    tail -115 "$work/guest/run/simh.log" >&2
    exit 1
}
if grep -Eq 'SIM-ERROR|Sockets: bind error' "$work/guest/run/simh.log"; then
    echo 'v1594: simulator reported a failed device/port attachment' >&2
    exit 1
fi
python3 "$self/daimos-fsinfo-dsk-root-verify-v1594.py" --self-test \
    "$work/guest/run/simh.log" \
    "$work/guest/build/system/boot/pdp6/disk" \
    "$work/v1594-physical-verification.txt"
echo 'PASS v1594: genuine physical DSK root publishes six mount slots'
