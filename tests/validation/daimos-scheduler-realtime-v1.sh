#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-scheduler-realtime-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$user"
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
    -S "$self/daimos-scheduler-realtime-v1.c" \
    -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" \
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=3 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

boot="$build/system/boot/pdp6"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 40s stdbuf -o0 -e0 \
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
*) cat "$out" >&2; echo "$tag: RT sentinel missing" >&2; exit 1 ;;
esac
text=${text%%HALT*}
case "$text" in
*'!'*|*'E'*|*'I'*|*'Y'*|*'D'*|*'O'*)
        cat "$out" >&2
        echo "$tag: target process reported failure" >&2
        exit 1
        ;;
esac

case "$text" in
R*) ;;
*)
        cat "$out" >&2
        echo "$tag: normal process ran during CPU-bound RT ownership" >&2
        exit 1
        ;;
esac

case "$text" in
*RS*b*q*W*|*RS*c*b*q*W*|*RS*b*c*q*W*|*RS*b*q*c*W*) ;;
*)
        cat "$out" >&2
        echo "$tag: blocking RT owner did not expose normal scheduling/exclusive owner" >&2
        exit 1
        ;;
esac

case "$text" in
*W*b*y*|*W*c*y*) ;;
*)
        cat "$out" >&2
        echo "$tag: RT yield did not let a normal process execute before return" >&2
        exit 1
        ;;
esac

case "$text" in
*d*X*2*|*d*X*3*|*2*d*X*|*3*d*X*) ;;
*)
        cat "$out" >&2
        echo "$tag: disable/exit completion markers missing" >&2
        exit 1
        ;;
esac

printf '%s\n' "$tag: PASS (RT quantum suppression, block/wake, exclusivity, yield, disable, exit)"
