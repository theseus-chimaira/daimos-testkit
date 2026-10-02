#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-rt-required-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$user"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
inc="-I$DAIMOS_REPO/system/kernel/boot \
-I$DAIMOS_REPO/system/kernel/core \
-I$DAIMOS_REPO/system/kernel/drivers \
-I$DAIMOS_REPO/system/kernel/fs \
-I$DAIMOS_REPO/system/kernel/mm \
-I$DAIMOS_REPO/system/kernel/modules \
-I$DAIMOS_REPO/system/kernel/proc \
-I$DAIMOS_REPO/system/kernel/storage \
-I$DAIMOS_REPO/userland/libc"

for n in init child; do
        src="$(dirname "$0")/daimos-rt-required-v1.c"
        [ "$n" = child ] && src="$(dirname "$0")/daimos-rt-required-v1-child.c"
        "$cc" -std=c99 -Os $inc -S "$src" -o "$user/$n.s"
        "$das" -C -F -O "$user/$n.dobj" "$user/$n.s"
done
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"
"$dlink" --rt-required -b 020 -o "$user/child.dxr" "$user/crt0.dobj" "$user/syscall.dobj" "$user/child.dobj" "$libgcc"
"$PDP10_PREFIX/bin/d6lz" -X "$user/child.dxr" "$user/child-compressed.dxr"

PATH="$PDP10_PREFIX/bin:$PATH" "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$user/init.dxr" \
    SYSTEM_TSFSPROBE_DXR="$user/child-compressed.dxr" >/dev/null

boot="$build/system/boot/pdp6"
set +e
(cd "$boot" && TERM=dumb timeout -k 2s 30s stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi
text=$(tr -d '\r\n' <"$out")
case "$text" in
*'<RBRA>'*) ;;
*) cat "$out" >&2; echo "$tag: admission/release markers missing" >&2; exit 1 ;;
esac
echo "$tag: PASS (compressed RT-required admission, rejection, release)"
