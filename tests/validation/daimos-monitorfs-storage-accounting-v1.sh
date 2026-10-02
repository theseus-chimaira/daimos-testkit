#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-monitorfs-storage-accounting-v1
work=$TMPDIR/$tag-$$
build=$work/build
user=$work/user
out=$work/simh.out
clean=$work/simh.clean
src=$(CDPATH= cd -- "$(dirname "$0")" && pwd)/daimos-monitorfs-storage-accounting-v1.c
cc=$PDP10_PREFIX/bin/pdp10-dec-none-gcc
das=$PDP10_PREFIX/bin/das
dlink=$PDP10_PREFIX/bin/dlink
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$user"

"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$src" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot=$build/system/boot/pdp6

set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 45s stdbuf -o0 -e0 "$simh" boot.ini
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi
tr -d '\r\n' < "$out" > "$clean"
text=$(cat "$clean")
case "$text" in
*'!'*)
        cat "$out" >&2
        echo "$tag: target validation failed" >&2
        exit 1
        ;;
*'S'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "$tag: completion marker missing" >&2
        exit 1
        ;;
esac

printf '%s\n' "$tag: PASS (D6SET logical and DSK physical read/write accounting)"
