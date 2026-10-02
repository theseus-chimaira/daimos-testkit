#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-multiuser-auth-runtime-v1
work="$TMPDIR/$tag-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

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
    -S "$(dirname "$0")/$tag.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$work/build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$work/user/init.dxr" >/dev/null

set +e
(cd "$work/build/system/boot/pdp6" && TERM=dumb timeout -k 2s 30s \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/out" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { cat "$work/out" >&2; exit 1; }
grep -q 'P' "$work/out" || { cat "$work/out" >&2; exit 1; }
printf '%s\n' "$tag: PASS"
