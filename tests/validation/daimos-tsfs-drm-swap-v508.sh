#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-tsfs-drm-swap-v508
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
trap 'if [ "${KEEP_V508_FILES:-0}" != 1 ]; then rm -rf "$work"; else echo "v508 diagnostics: $work" >&2; fi' EXIT HUP INT TERM
mkdir -p "$user"

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
    -S "$self/daimos-swap-wait-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

grep -Eq '^_start[[:space:]]+000020$' "$user/init.map" || {
        echo "$tag: test INIT is not linked at logical 020" >&2
        exit 1
}

PATH="$PDP10_PREFIX/bin:$PATH" make \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" \
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 BOOT_PROFILE=lowmem \
    COMPILER=gcc ROOT=tape \
    DAS_REPO="$DAS_REPO" \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

boot="$build/system/boot/pdp6"
# Assert the actual TSFS manifest carries the test INIT before booting.
manifest="$boot/tsfs-root.manifest"
grep -F "F /SYSTEM/INIT $user/init.dxr " "$manifest" || {
    echo "$tag: TSFS manifest does not contain custom INIT" >&2
    exit 1
}
# Provision only a private temporary image. Never touch the default disk.
aux="$work/aux.dsk"
"$PDP10_PREFIX/bin/mkauxstore" --blank "$aux" --blocks 020000
"$PDP10_PREFIX/bin/mkauxstore" -i "$aux" --confirm-destructive \
    --d6fs-base 1 --d6fs-blocks 07000 \
    --d6fs-super-a 0 --d6fs-super-b 1 \
    --backstore-blocks 01000 --logstore-blocks 0 --cache-blocks 07777
sed "s|$boot/drum/dsk0.dsk|$aux|g" "$boot/boot.ini" > "$boot/aux-source.ini"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/aux-source.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 180s stdbuf -o0 -e0 \
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
*'INIT V1'*)
        echo "$tag: unexpected stock INIT; custom TSFS INIT not executing" >&2
        echo "$tag: inspect preserved image/TSFS startup (KEEP_V508_FILES=1)" >&2
        exit 1
        ;;
esac
case "$text" in
*'!'*)
        cat "$out" >&2
        echo "$tag: target process reported failure" >&2
        exit 1
        ;;
esac
case "$text" in
*'r'*'a'*'p'*'b'*'S'*'W'*'P'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "$tag: swap/wake/WAIT completion markers missing" >&2
        exit 1
        ;;
esac

printf '%s\n' "$tag: PASS (32K TSFS DRM0 AUXST1 sleeping pipe reader swap-out, wake, slot-0 swap-in, WAIT status)"
