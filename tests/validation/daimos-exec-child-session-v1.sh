#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-exec-child-session-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
out="$work/simh.out"

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
"$cc" -std=c99 -Os $incs -S "$self/$tag.c" -o "$user/init.s"
"$das" -F -C -O "$user/init.dobj" "$user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/u.dobj" \
    "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot="$build/system/boot/pdp6"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 15s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" boot.ini
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
*'<'*'x'*'E'*'P'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "$tag: child session EXEC did not complete" >&2
        exit 1
        ;;
esac
case "$text" in
*'!'*)
        cat "$out" >&2
        echo "$tag: child session EXEC reported failure" >&2
        exit 1
        ;;
esac
printf '%s\n' "$tag: PASS (session-leader child survives EXEC and parent reaps it)"
