#!/bin/sh
# Independent sustained 48K INIT smoke using the strict source-built
# 64K-capable TSFS KINIT image, with actual physical RAM set to 48K.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1669-runtime48.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1669 48K runtime evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

boot=${V1669_STRICT_BUILD:-$work/build}
if [ -z "${V1669_STRICT_BUILD:-}" ]; then
    make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" \
        ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
        BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
        TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
        DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
        DAIMOS_SWAPLESS_ONLY_V1668=1 \
        > "$work/build.log" 2>&1 || {
        tail -70 "$work/build.log" >&2; keep=1; exit 1;
    }
fi
test -s "$boot/boot.ini"
test -s "$boot/kinit.dxr"
grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
if grep -q '^proc_swap_mres_package_v481[[:space:]]' \
    "$boot/kinit.map"; then
    echo 'FAIL v1669: runtime48 image contains DISK SWAP candidate' >&2
    exit 1
fi
for n in 0 1 2; do test -s "$boot/media/dtc$n.tap"; done
awk '
    /^attach -q (dsk[0-9]+|dr[0-9]+) / {next}
    /^set cpu [0-9]+k$/ {print "set cpu 48k"; next}
    {print}
' "$boot/boot.ini" > "$work/noaux-48.ini"
grep -qx 'set cpu 48k' "$work/noaux-48.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' \
    "$work/noaux-48.ini"; then
    echo 'FAIL v1669: 48K test has auxiliary backing' >&2
    exit 1
fi
port=$((33400 + ($$ % 6000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux-48.ini" "$work/headless.ini" \
    "$port" "$((port + 14000))"
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s "${V1669_RUNTIME_TIMEOUT:-100}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) > "$work/console.log" 2>&1
rc=$?
set -e
tr -d '\r' < "$work/console.log" > "$work/console.clean"
if [ "$rc" -ne 124 ]; then
    tail -70 "$work/console.clean" >&2
    echo "FAIL v1669: unexpected 48K simulator exit $rc" >&2
    keep=1; exit 1
fi
for marker in 'MEM                                  48 K' \
    'DTC                                   OK' \
    'PURE                              LOADED' 'INIT V1'; do
    if ! grep -F "$marker" "$work/console.clean" >/dev/null; then
        tail -70 "$work/console.clean" >&2
        echo "FAIL v1669: missing 48K marker $marker" >&2
        keep=1; exit 1
    fi
done
if grep -Eq 'SWAP[[:space:]]+FAIL|INIT: (RUN|RESPAWN) FAILED|\?RT' \
    "$work/console.clean"; then
    tail -70 "$work/console.clean" >&2
    echo 'FAIL v1669: 48K runtime boot contains failure' >&2
    keep=1; exit 1
fi
echo 'PASS v1669: physical 48K TSFS/no-AUX PURE LOADED, INIT V1, sustained'
