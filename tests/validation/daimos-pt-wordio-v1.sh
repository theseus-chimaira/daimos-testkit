#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-pt-wordio-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
input="$work/ptr-input.pt"
mkdir -p "$user"
trap 'rm -rf "$work"' EXIT HUP INT TERM

printf '\001\177\200\377\021\042\063\104' >"$input"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/ipc" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$(dirname "$0")/daimos-pt-wordio-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot="$build/system/boot/pdp6"
ptp="$boot/media/ptp.out"
# Reattach PTR only after KINIT has finished reading the bootstrap tape.  The
# expect action stops at the exact target marker and resumes after reattachment.
sed -i "/^go 020$/i expect \"PTRREADY\" detach ptr; attach -q ptr $input; deposit ptr time 1; continue" \
    "$boot/boot.ini"

set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 45s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" boot.ini
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi
case "$(tr -d '\r\n' <"$out")" in
*'!'*) cat "$out" >&2; echo "$tag: target failure" >&2; exit 1 ;;
*'PTRREADY'*'PTPASS'*'HALT'*) ;;
*) cat "$out" >&2; echo "$tag: markers/HALT missing" >&2; exit 1 ;;
esac

[ -f "$ptp" ] || { echo "$tag: PTP output missing" >&2; exit 1; }
actual=$(od -An -v -tu1 "$ptp" | tr -s ' ' | tr '\n' ' ')
case "$actual" in
*' 1 127 128 255 17 34 51 '*) ;;
*)
        od -An -v -tx1 "$ptp" >&2
        echo "$tag: wrong PTP byte stream: $actual" >&2
        exit 1
        ;;
esac
[ "$(wc -c <"$ptp" | tr -d ' ')" -eq 7 ] || {
        echo "$tag: PTP output is not exactly 7 bytes" >&2
        exit 1
}
printf '%s\n' "$tag: PASS (PTR/PTP WORDTOKEN8 full+partial physical round trip)"
