#!/bin/sh
# True 256K PDP-6 EXEC allocation pressure and low-memory retry validation.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-exec-pressure-v201
stage0_flags=
small_image=0
case "${DAIMOS_EXEC_V201_CONTROL:-0}" in
    0) ;;
    1) tag=daimos-exec-pressure-control-v201
       stage0_flags=-DTEST_V201_NO_PRESSURE=1 ;;
    *) echo 'invalid DAIMOS_EXEC_V201_CONTROL' >&2; exit 2 ;;
esac
case "${DAIMOS_EXEC_V201_SMALL_IMAGE:-0}" in
    0) ;;
    1) if [ -n "$stage0_flags" ]; then
           echo 'control and small-image modes are exclusive' >&2; exit 2
       fi
       tag=daimos-exec-pressure-small-v201
       stage0_flags=-DTEST_V201_SMALL_IMAGE=1
       small_image=1 ;;
    *) echo 'invalid DAIMOS_EXEC_V201_SMALL_IMAGE' >&2; exit 2 ;;
esac
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
    stage_flags=
    if [ "$stage" -eq 0 ]; then stage_flags=$stage0_flags; fi
    "$cc" -std=c99 -Os -DTEST_V201_STAGE="$stage" $stage_flags $incs -S \
        "$self/daimos-exec-pressure-v201.c" -o "$obj/stage$stage.s"
    "$das" -F -C -O "$obj/stage$stage.dobj" "$obj/stage$stage.s"
    "$dlink" -b 020 -M "$obj/stage$stage.map" \
        -o "$obj/stage$stage.dxr" "$obj/crt0.dobj" \
        "$obj/syscall.dobj" "$obj/stage$stage.dobj" "$libgcc"
done

# Transform only the second stage: preserve its real linked code and
# relocation map, pad its VM image, and compress the zero extension.
stage1_dxr="$obj/stage1.dxr"
if [ "$small_image" -eq 0 ]; then
    "${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra \
        "$self/daimos-exec-pressure-pad-v201.c" -o "$obj/pad-v201"
    "$obj/pad-v201" "$obj/stage1.dxr" "$obj/stage1.padded.dxr"
    "$PDP10_PREFIX/bin/d6lz" -x "$obj/stage1.padded.dxr" \
        "$obj/stage1.large.dxr"
    stage1_dxr="$obj/stage1.large.dxr"
fi

PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$obj/stage0.dxr" \
    SYSTEM_TSFSPROBE_DXR="$stage1_dxr" >/dev/null

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
if [ "$small_image" -eq 1 ]; then
    echo "$tag: PASS (ordinary EXEC succeeds after parent heap growth)"
elif [ -n "$stage0_flags" ]; then
    echo "$tag: PASS (padded and compressed large DXR replaces PID 1 without pressure)"
else
    echo "$tag: PASS (physical staged-VM allocation impossible; low-memory EXEC replaced PID 1 successfully)"
fi
