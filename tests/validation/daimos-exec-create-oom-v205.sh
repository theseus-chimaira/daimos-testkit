#!/bin/sh
# True 256K PDP-6 staged EXEC VM allocation failure/low-memory retry v205.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-exec-create-oom-v205
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/$tag-$$"
obj="$work/obj"
boot="$work/build/system/boot/pdp6"
out="$work/simh.out"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$obj"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core \
-I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs \
-I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules \
-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage \
-I$DAIMOS_REPO/userland/libc"

"$das" -F -C -O "$obj/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$obj/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
for stage in 0 1; do
    "$cc" -std=c99 -Os -DTEST_V205_STAGE="$stage" $incs -S \
        "$self/daimos-exec-create-oom-v205.c" -o "$obj/stage$stage.s"
    "$das" -F -C -O "$obj/stage$stage.dobj" "$obj/stage$stage.s"
    "$dlink" -b 020 -M "$obj/stage$stage.map" \
        -o "$obj/stage$stage.dxr" "$obj/crt0.dobj" \
        "$obj/syscall.dobj" "$obj/stage$stage.dobj" "$libgcc"
    grep -Eq '^_start[[:space:]]+000020$' "$obj/stage$stage.map" || {
        echo "$tag: bad user entry for stage $stage" >&2; exit 1;
    }
done

# Preserve linked code/entry/relocations; pad to 0100000 image words.
# Keep the DXR uncompressed to test VM exhaustion independently of D6LZ.
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra \
    "$self/daimos-exec-create-oom-pad-v205.c" -o "$obj/pad-v205"
"$obj/pad-v205" "$obj/stage1.dxr" "$obj/stage1.padded.dxr"
report=$("$PDP10_PREFIX/bin/dxrcheck" "$obj/stage1.padded.dxr")
printf '%s\n' "$report" | grep -Eq '^DXR image=0?100000 bss=0?77000 ' || {
        echo "$tag: replacement DXR does not match memory contract" >&2
        printf '%s\n' "$report" >&2
        exit 1
    }

PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$obj/stage0.dxr" \
    SYSTEM_TSFSPROBE_DXR="$obj/stage1.padded.dxr" >/dev/null
grep '^__kcore_low_end' "$boot/kcore.map" || {
    echo "$tag: linked KCORE endpoint missing" >&2; exit 1;
}

set +e
(cd "$boot" && TERM=dumb timeout -k 2s 60s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    cat "$out" >&2
    echo "$tag: simulator exit $rc" >&2
    exit 1
fi
text=$(tr -d '\r\n' <"$out")
case "$text" in
    *'<HE'*'HALT'*) ;;
    *) cat "$out" >&2; echo "$tag: pressured EXEC did not replace PID 1" >&2; exit 1 ;;
esac
case "$text" in
    *'!'*) cat "$out" >&2; echo "$tag: failure marker present" >&2; exit 1 ;;
esac
echo "$tag: PASS (staged VM cannot fit physically; low-memory EXEC replaced PID 1)"
