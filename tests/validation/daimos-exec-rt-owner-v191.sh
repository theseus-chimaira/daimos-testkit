#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
: "${DAIMOS_EXEC_OBSERVE_SECONDS:=15}"
case "$DAIMOS_EXEC_OBSERVE_SECONDS" in
    ''|*[!0-9]*) echo 'v191: invalid observation seconds' >&2; exit 2 ;;
esac

tag=daimos-exec-rt-owner-v191
work="$TMPDIR/$tag-$$"
user="$work/user"
boot="$work/build/system/boot/pdp6"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$user"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core \
-I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs \
-I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules \
-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage \
-I$DAIMOS_REPO/userland/libc"

"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$user/u.s"
"$das" -F -C -O "$user/u.dobj" "$user/u.s"
libgcc=$($cc -print-libgcc-file-name)

for stage in 0 1 2; do
    "$cc" -std=c99 -Os -DTEST_RT_STAGE="$stage" $incs -S \
        "$self/daimos-exec-rt-owner-v191.c" -o "$user/stage$stage.s"
    "$das" -F -C -O "$user/stage$stage.dobj" "$user/stage$stage.s"
    if [ "$stage" -eq 1 ]; then
        "$dlink" --rt-required -b 020 -o "$user/stage$stage.dxr" \
            "$user/crt0.dobj" "$user/syscall.dobj" \
            "$user/u.dobj" "$user/stage$stage.dobj" "$libgcc"
    else
        "$dlink" -b 020 -o "$user/stage$stage.dxr" \
            "$user/crt0.dobj" "$user/syscall.dobj" \
            "$user/u.dobj" "$user/stage$stage.dobj" "$libgcc"
    fi
done

PATH="$PDP10_PREFIX/bin:$PATH" \
    "${MAKE:-make}" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/stage0.dxr" \
    SYSTEM_TSFSPROBE_DXR="$user/stage1.dxr" \
    SYSTEM_DSH_DXR="$user/stage2.dxr" >/dev/null

dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
set +e
(cd "$boot" && TERM=dumb timeout -k 2s "${DAIMOS_EXEC_OBSERVE_SECONDS}s" \
    stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" boot.headless.ini) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    cat "$out" >&2
    echo "$tag: simulator failed: $rc" >&2
    exit 1
fi
text=$(tr -d '\r\n' <"$out")
case "$text" in
    *'<abcdRN'*'HALT'*) ;;
    *) cat "$out" >&2; echo "$tag: rollback/admission/release markers missing" >&2; exit 1 ;;
esac
case "$text" in
    *'!'*) cat "$out" >&2; echo "$tag: failure marker detected" >&2; exit 1 ;;
esac
echo "$tag: PASS (RT rollback at header and post-VM decoder failure, preserved owner, admission and release)"
