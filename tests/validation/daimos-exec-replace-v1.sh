#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-exec-replace-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
out="$work/simh.out"
boot_mk="$DAIMOS_REPO/system/boot/pdp6/Makefile"

# The target replacement must actually be present on the D6FS image.
grep -q 'SYSTEM_DSH_DXR' "$boot_mk" || {
        echo "$tag: boot image has no install slot for replacement image" >&2
        exit 1
}
grep -q '/SYSTEM/EXEC/DSH' "$boot_mk" || {
        echo "$tag: replacement image is not installed as /SYSTEM/EXEC/DSH" >&2
        exit 1
}

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$user"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc"

"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$user/u.s"
"$das" -F -C -O "$user/u.dobj" "$user/u.s"
libgcc=$($cc -print-libgcc-file-name)

for part in init next; do
        "$cc" -std=c99 -Os $incs -S "$self/daimos-exec-replace-v1-$part.c" \
            -o "$user/$part.s"
        "$das" -F -C -O "$user/$part.dobj" "$user/$part.s"
        "$dlink" -b 020 -o "$user/$part.dxr" -M "$user/$part.map" \
            "$user/crt0.dobj" "$user/syscall.dobj" "$user/u.dobj" \
            "$user/$part.dobj" "$libgcc"
done

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$user/init.dxr" \
    SYSTEM_DSH_DXR="$user/next.dxr" >/dev/null
boot="$build/system/boot/pdp6"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 15s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" boot.headless.ini
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi
text=$(tr -d '\r\n' <"$out")
case "$text" in
*'<'*) text=${text#*<} ;;
*) cat "$out" >&2; echo "$tag: pre-EXEC sentinel missing" >&2; exit 1 ;;
esac
case "$text" in
*'!'*) cat "$out" >&2; echo "$tag: EXEC replacement reported failure" >&2; exit 1 ;;
esac
case "$text" in
*'E'*'HALT'*) ;;
*) cat "$out" >&2; echo "$tag: replacement image/HALT missing" >&2; exit 1 ;;
esac
printf '%s\n' "$tag: PASS (EXEC replaces current image and preserves PID, credentials, cwd, session, pgrp, TTY and descriptors)"
