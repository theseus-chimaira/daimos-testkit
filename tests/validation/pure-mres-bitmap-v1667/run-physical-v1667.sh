#!/bin/sh
# v1667 64K PDP-6 staged PURE bitmap MRES boot, optional PURE, and *no*
# attached DSK/DRM backing. Verify the real KINIT install witness.
#
# This accepts boot reachability only, not RAW pressure/reclaim.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-boot-v1667.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1667: physical guest evidence $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

boot=${PURE_BOOT_BUILD_V1667:-$work/build}
if [ -z "${PURE_BOOT_BUILD_V1667:-}" ]; then
    make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape \
        BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
        BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
        TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
        DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=1 >"$work/build.log" 2>&1 || {
        tail -70 "$work/build.log" >&2
        keep=1
        exit 1
    }
fi

test -s "$boot/boot.ini"
test -s "$boot/kinit.dxr"
test -s "$boot/purev1612-mres.dobj"
for n in 0 1 2; do
    test -s "$boot/media/dtc$n.tap"
done
grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
# v1667 moved RAW owner teardown out of fixed KCORE: GCC 024076.
grep -q '^__kcore_low_end[[:space:]]*024076' "$boot/kcore.map"
grep -q '^proc_swap_term_v1666[[:space:]]' "$boot/kcore.map"
grep -q '^pdp6_pure_detach_v1609[[:space:]]' \
    "$boot/pure-mres-v1612.map"
grep -q '^proc_pure_term_v1667[[:space:]]' \
    "$boot/pure-mres-v1612.map"
grep -q '^proc_pure_bitmap_restore_v1664[[:space:]]' \
    "$boot/pure-mres-v1612.map"
if grep -q '^pdp6_pure_detach_v1609[[:space:]]' "$boot/kcore.map"; then
    echo 'FAIL v1667: RAW terminal scanner still linked in KCORE' >&2
    exit 1
fi
grep -qx 'set cpu 64k' "$boot/boot.ini"

# Neither the installed backing descriptor nor a leftover drum image
# may remain visible to AUXSTORE discovery in the simulator.
# DTC0-2 are the actual TSFS root tapes; DSK and DRM are not attached.
awk '!/^attach -q (dsk[0-9]+|dr[0-9]+) /' \
    "$boot/boot.ini" >"$work/noaux.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' "$work/noaux.ini"; then
    echo 'FAIL v1667: auxiliary physical media remained attached' >&2
    exit 1
fi
grep -q '^attach -q dtc0 ' "$work/noaux.ini"
port=$((34000 + ($$ % 12000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/headless.ini" "$port" "$((port+13000))"

timeout_s=${PURE_BOOT_TIMEOUT_V1667:-75}
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s "$timeout_s" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/console.log" 2>&1
rc=$?
set -e
# An INIT that remains alive until the controlled time limit is
# evidence of sustained boot, unlike a simulator that HALTed early.
if [ "$rc" -ne 124 ]; then
    tail -65 "$work/console.log" >&2
    echo "FAIL v1667: simulator exited prematurely: $rc" >&2
    keep=1
    exit 1
fi
tr -d '\r' <"$work/console.log" >"$work/console.clean"
for marker in 'MEM                                  64 K' \
    'DTC                                   OK' \
    'PURE                              LOADED' \
    'INIT V1'; do
    if ! grep -F "$marker" "$work/console.clean" >/dev/null; then
        tail -65 "$work/console.clean" >&2
        echo "FAIL v1667: physical witness missing: $marker" >&2
        keep=1
        exit 1
    fi
done
if grep -Eq '\?RT|INIT: (RUN|RESPAWN) FAILED' "$work/console.clean"; then
    tail -65 "$work/console.clean" >&2
    echo 'FAIL v1667: root failure or INIT process failure' >&2
    keep=1
    exit 1
fi
echo 'PASS v1667: physical PDP-6 64K TSFS, absent AUXST1, PURE LOADED, INIT V1'
