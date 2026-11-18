#!/bin/sh
# Actual 64K PDP-6 TSFS root: absent swap boots PURE, positive
# validated BACKSTORE HALTs before PURE or INIT (no disk MRES linked).
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1668-physical.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1668 physical evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

boot=${V1668_BOOT_BUILD:-$work/build}
if [ -z "${V1668_BOOT_BUILD:-}" ]; then
    make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
        ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
        BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
        TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
        DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
        DAIMOS_SWAPLESS_ONLY_V1668=1 \
        BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" \
        > "$work/build.log" 2>&1 || {
        tail -85 "$work/build.log" >&2; keep=1; exit 1;
    }
fi

test -s "$boot/kinit.dxr"
test -s "$boot/boot.ini"
test -s "$boot/kinit.map"
test -s "$boot/purev1612-mres.dobj"
grep -q '^__kcore_low_end[[:space:]]*024076' "$boot/kcore.map"
grep -q '^proc_swap_term_v1666[[:space:]]' "$boot/kcore.map"
grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
if grep -q '^proc_swap_mres_package_v481[[:space:]]' "$boot/kinit.map"; then
    echo 'FAIL v1668: disk-swap candidate linked into strict KINIT' >&2
    exit 1
fi
grep -q '^.set DAIMOS_SWAPLESS_ONLY_V1668,1$' \
    "$boot/module-table-runtime.s"
grep -qx 'set cpu 64k' "$boot/boot.ini"
for n in 0 1 2; do
    test -s "$boot/media/dtc$n.tap"
done

# Both runs use the EXACT same image. Only the attached physical
# auxiliary backing differs; root remains DTC on three DECtapes.
awk '!/^attach -q (dsk[0-9]+|dr[0-9]+) /' \
    "$boot/boot.ini" > "$work/noaux.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' \
    "$work/noaux.ini"; then
    echo 'FAIL v1668: no-AUX test retains disk/drum backing' >&2
    exit 1
fi

awk '!/^attach -q (dsk[0-9]+|dr[1-9][0-9]*) /' \
    "$boot/boot.ini" > "$work/positive.ini"
if ! grep -q '^attach -q dr0 ' "$work/positive.ini" || \
    grep -Eq '^attach -q (dsk[0-9]+|dr[1-9][0-9]*) ' \
        "$work/positive.ini"; then
    echo 'FAIL v1668: positive test lacks independent DRM0 AUXST1' >&2
    exit 1
fi

run_guest()
{
    name=$1
    source_ini=$2
    seconds=$3
    port=$((32000 + ($$ % 7000)))
    if [ "$name" = positive ]; then
        port=$((port + 1000))
    fi
    sh "$kit/tests/lib/daimos-simh-headless.sh" "$source_ini" \
        "$work/$name-headless.ini" "$port" "$((port+14000))"
    set +e
    (
        cd "$boot"
        TERM=dumb timeout -k 3s "$seconds" \
            stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" \
            "$work/$name-headless.ini"
    ) > "$work/$name-console.log" 2>&1
    rc=$?
    set -e
    tr -d '\r' < "$work/$name-console.log" > \
        "$work/$name-console.clean"
    echo "$rc" > "$work/$name-rc.txt"
}

run_guest noaux "$work/noaux.ini" "${V1668_NOAUX_TIMEOUT:-80}"
if [ "$(cat "$work/noaux-rc.txt")" -ne 124 ]; then
    tail -65 "$work/noaux-console.clean" >&2
    echo 'FAIL v1668: no-AUX guest exited before controlled timeout' >&2
    keep=1; exit 1
fi
for marker in 'MEM                                  64 K' \
    'DTC                                   OK' \
    'PURE                              LOADED' 'INIT V1'; do
    if ! grep -F "$marker" "$work/noaux-console.clean" >/dev/null; then
        tail -65 "$work/noaux-console.clean" >&2
        echo "FAIL v1668: no-AUX boot missing $marker" >&2
        keep=1; exit 1
    fi
done
if grep -Eq '\?RT|INIT: (RUN|RESPAWN) FAILED|SWAP[[:space:]]+FAIL' \
    "$work/noaux-console.clean"; then
    echo 'FAIL v1668: no-AUX boot contains KINIT/INIT error' >&2
    keep=1; exit 1
fi
echo 'v1668: physical 64K DTC no-AUX PURE LOADED and INIT V1 PASS'

run_guest positive "$work/positive.ini" "${V1668_POS_TIMEOUT:-65}"
if [ "$(cat "$work/positive-rc.txt")" -ne 0 ] || \
    ! grep -Eq 'SWAP[[:space:]]+FAIL' \
        "$work/positive-console.clean" || \
    ! grep -q 'HALT instruction, PC:' \
        "$work/positive-console.clean" || \
    grep -Eq 'PURE[[:space:]]+LOADED|INIT V1' \
        "$work/positive-console.clean"; then
    tail -65 "$work/positive-console.clean" >&2
    echo 'FAIL v1668: positive validated BACKSTORE was not fail-stop' >&2
    keep=1; exit 1
fi
echo 'v1668: physical 64K DTC + DRM0 BACKSTORE SWAP FAIL/HALT PASS'
