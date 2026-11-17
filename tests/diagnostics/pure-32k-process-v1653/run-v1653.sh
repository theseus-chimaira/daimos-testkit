#!/bin/sh
# Real original PDP-6 32K ROOT/TSFS no-AUX PURE opt-in lifecycle.
set -eu
: "${DAIMOS_REPO:?original DAIMOS checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-32k-v1653.XXXXXX")
trap 'echo "v1653 physical PDP-6 32K evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$work/dlink-v1653"
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$dlink" "$DAIMOS_REPO/tools/host/dlink.c" \
    "$DAIMOS_REPO/tools/host/dobj.c"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
"$cc" -std=c89 -Os $incs -S "$here/test-v1653.c" \
    -o "$work/user/init-v1653.s"
"$das" -C -F -O "$work/user/init-v1653.dobj" \
    "$work/user/init-v1653.s"
"$das" -C -F -O "$work/user/crt0-v1653.dobj" \
    "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall-v1653.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" --pure -b 020 -o "$work/user/init-v1653.dxr" \
    -M "$work/user/init-v1653.map" \
    "$work/user/crt0-v1653.dobj" \
    "$work/user/syscall-v1653.dobj" \
    "$work/user/init-v1653.dobj" "$libgcc"
"$PDP10_PREFIX/bin/dxrcheck" -d "$work/user/init-v1653.dxr" \
    >"$work/user/dxrcheck-v1653.log"
grep -q 'purity=PURE' "$work/user/dxrcheck-v1653.log"

boot="$work/build"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS=0100000 SIMH_CPU_KWORDS=32 \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED=1 \
    SYSTEM_INIT_DXR="$work/user/init-v1653.dxr" \
    >"$work/build-v1653.log" 2>&1 || {
        tail -65 "$work/build-v1653.log" >&2
        exit 1
    }
grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
grep -qx 'set cpu 32k' "$boot/boot.ini"
awk '!/^attach -q (dsk[0-9]+|dr[0-9]+) /' \
    "$boot/boot.ini" >"$work/noaux.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' "$work/noaux.ini"; then
    echo 'FAIL v1653: auxiliary media unexpectedly attached' >&2
    exit 1
fi
port=$((34000 + ($$ % 11000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/headless.ini" "$port" "$((port+13000))"
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s "${PURE_32K_TIMEOUT_V1653:-260}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/console.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/console.log" >"$work/console.clean"
if [ "$rc" -ne 0 ]; then
    tail -75 "$work/console.clean" >&2
    echo "FAIL v1653: original 32K SIMH status=$rc" >&2
    exit 1
fi
for marker in 'MEM                                  32 K' \
              'PURE                              LOADED' \
              'DTFS                              LOADED' \
              'HALT instruction, PC: 000000'; do
    grep -F "$marker" "$work/console.clean" >/dev/null
done
grep -q 'BcZ' "$work/console.clean"
if grep -q '!' "$work/console.clean"; then
    tail -60 "$work/console.clean" >&2
    echo 'FAIL v1653: userland reported a failure' >&2
    exit 1
fi
echo 'PASS v1653: original PDP-6 32K CORE/TSFS no-AUX PURE RUN/WAIT'
