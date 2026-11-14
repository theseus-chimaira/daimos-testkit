#!/bin/sh
# Deterministic real PDP-6 PID1/PID2 race against published V2 seal.
# Only the disposable KCORE copy receives a scheduler delay AFTER the
# production barrier is armed, BEFORE the real provider SYNC executes.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-race-v1565.XXXXXX")
if [ "${V1565_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1565: preserving isolated KCORE and simulator evidence: $work"
fi

base=${DAIMOS_V1565_BASE_BUILD:-}
if [ -z "$base" ]; then
    base="$work/base-build"
    echo 'v1565: building current unmodified KCC/256K base image'
    PATH="$PDP10_PREFIX/bin:$PATH" make \
        -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$base" USERLAND_BUILD_ROOT="$base" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/base-build-v1565.log" 2>&1 || {
        tail -90 "$work/base-build-v1565.log" >&2
        exit 1
    }
fi
test -f "$base/kcore-asm/vfs.s" && test -f "$base/kcore.map" && \
    test -f "$base/boot.ini" || {
    echo 'v1565: need a full source-matched KCC boot image' >&2
    exit 1
}

build="$work/guest-build"
mkdir -p "$build"
cp -a "$base/." "$build/"
echo 'v1565: instrumenting ONLY the disposable compiled VFS assembler'
python3 - "$DAIMOS_REPO" "$build/kcore-asm/vfs.s" <<'PY'
from pathlib import Path
import sys

repo = Path(sys.argv[1])
target = Path(sys.argv[2])
source = (repo / 'system/kernel/fs/vfs.s').read_text()
assert target.read_text() == source, (
    'the prebuilt KCORE VFS does not match the current production source')
anchor = (
    '        movem   1,-2(17)               ; 1 for V2, zero otherwise\n'
    '        move    1,-1(17)\n'
    '        pushj   17,vfs_sync\n')
assert source.count(anchor) == 1
injection = (
    '        movem   1,-2(17)               ; 1 for V2, zero otherwise\n'
    '        ; v1565 TEST ONLY: real timer-scheduler interleaving after\n'
    '        ; the real v1562 seal has been acquired and before SYNC.\n'
    '        ; This extends a legitimate sleeping-provider interval;\n'
    '        ; it does NOT change the VFS admission or retirement gates.\n'
    '        .globl vfs_unmount_test_sleep_done_v1565\n'
    '        skipn   -2(17)\n'
    '        jrst    vfs_unmount_test_sleep_done_v1565\n'
    '        movei   1,01400              ; 768 real 60-Hz ticks\n'
    '        pushj   17,proc_sleep_ticks\n'
    'vfs_unmount_test_sleep_done_v1565:\n'
    '        move    1,-1(17)\n'
    '        pushj   17,vfs_sync\n')
target.write_text('.globl proc_sleep_ticks\n' + source.replace(anchor, injection, 1))
print('PASS v1565: source-matched KCORE with real scheduler sleep at V2 seal')
PY

# The KCORE source stamp remains unchanged and the modified copied
# vfs.s is newer than all its original build dependencies. The ordinary
# production linker now regenerates the KCORE, MRES relocation and boot
# image in this disposable directory. Never patch the user's checkout.
PATH="$PDP10_PREFIX/bin:$PATH" make \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" USERLAND_BUILD_ROOT="$build" \
    ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
    > "$work/race-image-v1565.log" 2>&1 || {
    tail -100 "$work/race-image-v1565.log" >&2
    exit 1
}
grep -q 'vfs_unmount_test_sleep_done_v1565' "$build/kcore.map" || {
    echo 'v1565: injected sleep was not linked into the booted KCORE' >&2
    exit 1
}
test -f "$build/kcore.stream" || exit 1

export DAIMOS_TSFS_PREBUILT_BUILD="$build"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-race-v1565.c"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSRACE V1565'
export DAIMOS_TSFS_GATE_STAGES_V1526='START MOUNTED CHILD_START SEAL_OBSERVED OWNERS_REFUSED RETIRED RACE_PROVEN RETIRED_TSFS PASS'
echo 'v1565: launching physical PDP-6 with true two-process seal overlap'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo 'PASS v1565: real KCORE seal, independent scheduler, refused owner admissions'
