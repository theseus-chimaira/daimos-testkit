#!/bin/sh
# Native 256K PDP-6 regression: RUN late failure under live process pressure.
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-run-late-rollback-v197
extra_cflags=
case "${DAIMOS_RUN_VM_OOM_V198:-0}" in
    0) ;;
    1) tag=daimos-run-vm-oom-v198; extra_cflags=-DTEST_VM_OOM_V198=1 ;;
    *) echo 'invalid DAIMOS_RUN_VM_OOM_V198' >&2; exit 2 ;;
esac
case "${DAIMOS_RUN_VM_CREATE_OOM_V199:-0}" in
    0) ;;
    1) if [ -n "$extra_cflags" ]; then
           echo 'v198 and v199 variants are mutually exclusive' >&2; exit 2
       fi
       tag=daimos-run-create-oom-v199
       extra_cflags=-DTEST_VM_CREATE_OOM_V199=1 ;;
    *) echo 'invalid DAIMOS_RUN_VM_CREATE_OOM_V199' >&2; exit 2 ;;
esac
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/$tag-$$"
user="$work/user"
boot="$work/build/system/boot/pdp6"
out="$work/simh.out"
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

"$cc" -std=c99 -Os $extra_cflags $incs -S \
    "$self/daimos-run-late-rollback-v197.c" -o "$user/init.s"
"$das" -F -C -O "$user/init.dobj" "$user/init.s"
"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

large_image_arg=
if [ "$extra_cflags" = -DTEST_VM_CREATE_OOM_V199=1 ]; then
    "$cc" -std=c99 -Os $incs -S \
        "$self/daimos-run-create-oom-v199-child.c" -o "$user/large.s"
    "$das" -F -C -O "$user/large.dobj" "$user/large.s"
    "$dlink" -b 020 -o "$user/large.dxr" -M "$user/large.map" \
        "$user/crt0.dobj" "$user/syscall.dobj" "$user/large.dobj" "$libgcc"
    "$PDP10_PREFIX/bin/dxrcheck" -q "$user/large.dxr"
    large_image_arg="SYSTEM_TSFSPROBE_DXR=$user/large.dxr"
fi

grep -Eq '^_start[[:space:]]+000020$' "$user/init.map" || {
    echo "$tag: bad initial entry" >&2; exit 1;
}
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" $large_image_arg >/dev/null

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
    *'<VRCP'*'HALT'*) if [ "$extra_cflags" != -DTEST_VM_CREATE_OOM_V199=1 ]; then
                        cat "$out" >&2
                        echo "$tag: unexpected v199 marker" >&2; exit 1
                      fi ;;
    *'<RMCP'*'HALT'*) ;;
    *'<RCP'*'HALT'*) if [ -n "$extra_cflags" ]; then
                       cat "$out" >&2
                       echo "$tag: missing OOM marker" >&2
                       exit 1
                     fi ;;
    *) cat "$out" >&2; echo "$tag: rollback/cleanup/recovery markers missing" >&2; exit 1 ;;
esac
case "$text" in
    *'!'*) cat "$out" >&2; echo "$tag: guest failure marker detected" >&2; exit 1 ;;
esac
if [ "$extra_cflags" = -DTEST_VM_CREATE_OOM_V199=1 ]; then
    echo "$tag: PASS (4 valid RUN loader VM allocation failures, preserved caller, full recovery)"
elif [ -n "$extra_cflags" ]; then
    echo "$tag: PASS (4 physical MM OOM break requests, preserved caller VM and RUN rollback/recovery)"
else
    echo "$tag: PASS (16 post-VM RUN fdmap failures under three live children; stable process accounting and recovery)"
fi
