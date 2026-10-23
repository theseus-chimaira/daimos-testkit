#!/bin/sh
# Native 256K PDP-6 regression: RUN late failure under live process pressure.
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-run-late-rollback-v197
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

"$cc" -std=c99 -Os $incs -S \
    "$self/daimos-run-late-rollback-v197.c" -o "$user/init.s"
"$das" -F -C -O "$user/init.dobj" "$user/init.s"
"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

grep -Eq '^_start[[:space:]]+000020$' "$user/init.map" || {
    echo "$tag: bad initial entry" >&2; exit 1;
}
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

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
    *'<RCP'*'HALT'*) ;;
    *) cat "$out" >&2; echo "$tag: rollback/cleanup/recovery markers missing" >&2; exit 1 ;;
esac
case "$text" in
    *'!'*) cat "$out" >&2; echo "$tag: guest failure marker detected" >&2; exit 1 ;;
esac
echo "$tag: PASS (16 post-VM RUN fdmap failures under three live children; stable process accounting and recovery)"
