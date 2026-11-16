#!/bin/sh
# Non-accepting 48K PDP-6 sleeping-owner BRK/RAW/PIPE/WAIT
# diagnostic. A physical failure must retain its console and
# MM evidence; only promote to validation after actual slot-0
# restoration and exact MM owner preservation are demonstrated.
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
work=$(mktemp -d "$TMPDIR/pure-brk-pressure-v1614.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1614: pressure guest evidence $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/user"
cp "$here/test-v1614.c" "$work/user/init-v1614.c"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
# Build the actual DAIMOS host linker source so this test cannot
# accidentally use an older installed dlink whose PURE range check
# mistakes the PDP-10 AC register file for writable TEXT.
dlink="$work/dlink-v1614"
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$dlink" "$DAIMOS_REPO/tools/host/dlink.c" \
    "$DAIMOS_REPO/tools/host/dobj.c"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -S "$work/user/init-v1614.c" \
    -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
"$das" -C -F -O "$work/user/crt0.dobj" \
    "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" --pure -b 020 -o "$work/user/init.dxr" \
    -M "$work/user/init.map" "$work/user/crt0.dobj" \
    "$work/user/syscall.dobj" "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"
# A plain DXR (purity=UNKNOWN) is never eligible for RAW prefix DROP:
# reject that test-setup error before constructing any boot media.
"$PDP10_PREFIX/bin/dxrcheck" -d "$work/user/init.dxr" \
    >"$work/user/dxrcheck.log"
grep -q 'purity=PURE' "$work/user/dxrcheck.log" || {
    echo 'FAIL v1614: guest executable has no immutable PURE prefix' >&2
    exit 1
}

boot="$work/build"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED=1 \
    SYSTEM_INIT_DXR="$work/user/init.dxr" >"$work/build.log" 2>&1 || {
    tail -60 "$work/build.log" >&2
    keep=1
    exit 1
}
grep -F "F /SYSTEM/INIT $work/user/init.dxr " \
    "$boot/tsfs-root.manifest" >/dev/null
grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"

awk '!/^attach -q (dsk[0-9]+|dr[0-9]+) /' \
    "$boot/boot.ini" >"$work/noaux.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' "$work/noaux.ini"; then
    echo 'FAIL v1614: pressure guest still has auxiliary media' >&2
    exit 1
fi
port=$((32000 + ($$ % 15000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/headless.ini" "$port" "$((port+14000))"

set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s ${PURE_PRESSURE_TIMEOUT_V1614:-180} \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/console.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/console.log" >"$work/console.clean"
if ! grep -q 'PURE[[:space:]]*LOADED' "$work/console.clean"; then
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1614: PURE service was never installed' >&2
    keep=1
    exit 1
fi
if grep -q 'INIT V1' "$work/console.clean"; then
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1614: custom pressure INIT did not execute' >&2
    keep=1
    exit 1
fi
text=$(tr -d '\r\n' <"$work/console.clean")
case "$text" in
*'!'*)
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1614: pressure INIT reported a failed assertion' >&2
    keep=1
    exit 1
    ;;
esac
case "$text" in
*'a'*'[B'*'[A'*'R'*'w'*'Z'*'HALT'*) ;;
*)
    tail -75 "$work/console.clean" >&2
    echo "FAIL v1614: BRK/RAW/reclaim/wake/WAIT incomplete (sim=$rc)" >&2
    keep=1
    exit 1
    ;;
esac
echo 'PASS v1614: physical 48K TSFS no-AUX PURE BRK reclaim, wake and WAIT'
