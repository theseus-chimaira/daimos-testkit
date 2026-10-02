#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
tag=daimos-card-wordio-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
input="$work/card.in"
punch="$work/card.out"
mkdir -p "$user"
trap 'rm -rf "$work"' EXIT HUP INT TERM
line='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGH'
[ "${#line}" -eq 80 ] || { echo "$tag: internal card length error" >&2; exit 1; }
printf '%s\n' "$line" > "$input"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/ipc" -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" -I"$DAIMOS_REPO/userland/libc" \
    -S "$(dirname "$0")/daimos-card-wordio-v1.c" -o "$user/init.s"
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
sed -i "/^go 020$/i attach -q cr $input\ndetach cp\nattach -q -n cp $punch" "$boot/boot.ini"
set +e
( cd "$boot"; TERM=dumb timeout -k 2s 45s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini ) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then cat "$out" >&2; echo "$tag: simulator failed: $rc" >&2; exit 1; fi
case "$(tr -d '\r\n' <"$out")" in
*'!'*) cat "$out" >&2; echo "$tag: target failure" >&2; exit 1 ;;
*'CPASS'*'HALT'*) ;;
*) cat "$out" >&2; echo "$tag: markers/HALT missing" >&2; exit 1 ;;
esac
[ -f "$punch" ] || { echo "$tag: punch output missing" >&2; exit 1; }
actual=$(head -c 80 "$punch")
[ "$actual" = "$line" ] || { od -An -v -tx1 "$punch" >&2; echo "$tag: card round trip mismatch" >&2; exit 1; }
printf '%s\n' "$tag: PASS (80-column CR/CP WORDTOKEN12 physical round trip)"
