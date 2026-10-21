#!/bin/sh
# Exercise only the six single-mapped-pointer syscalls refactored in V97.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-kcore-oneptr-v97-v1
work="$TMPDIR/$tag-$$"
user="$work/user"
build="$work/build/system/boot/pdp6"
out="$work/simh.out"
mkdir -p "$user"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

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
    -S "$self/$tag.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$das" -C -F -O "$user/syscall_helpers.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall_helpers.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" \
    "$user/syscall_helpers.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    COMPILER=kcc BOOT_PROFILE=full ROOT=disk BOOT=dsk \
    SIMH_CPU_KWORDS=256 PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >"$work/build.log" 2>&1 || {
        tail -60 "$work/build.log" >&2
        exit 1
    }

set +e
(cd "$build"; TERM=dumb timeout -k 2s 35s \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$out" 2>&1
rc=$?
set -e
text=$(tr -d '\r\n' <"$out")
case "$text" in
*'<'*'P'*'HALT'*) ;;
*) rc=1 ;;
esac
if [ "$rc" -ne 0 ]; then
    cat "$out" >&2
    echo "$tag: FAIL" >&2
    exit 1
fi
case "${text#*<}" in
*'!'*) cat "$out" >&2; echo "$tag: target failure" >&2; exit 1 ;;
esac
echo "$tag: PASS (CHDIR GETCWD MKDIR UNLINK TRUNCATE MEMINFO + bad mapping)"
