#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-wcnsls-raw-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
debug="$work/wcnsls.debug"
ini="$work/runtime.ini"
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
    -S "$self/daimos-wcnsls-raw-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot="$build/system/boot/pdp6"

# Keep WCNSLS enabled but do not request the SDL color-scope window.  Device
# debug output proves that the userspace batch reaches physical CONO/DATAO.
sed \
    -e '/^set wcnsls cscope$/d' \
    -e '/^go 020$/,$d' \
    "$boot/boot.ini" >"$ini"
cat >>"$ini" <<EOF
set debug $debug
set wcnsls debug
go 020
exit
EOF

set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 30s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" "$ini"
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
*'<P'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "$tag: target raw/RT path did not complete" >&2
        exit 1
        ;;
esac
case "$text" in
*'<O'*|*'<R'*|*'<W'*|*'<I'*|*'<C'*)
        cat "$out" >&2
        echo "$tag: target reported WCNSLS failure" >&2
        exit 1
        ;;
esac

# Boot uses WCNSLS too, so match the distinctive userspace values rather than
# counting all operations in the trace.
grep -Eq 'WCNSLS.*CONO.*370040|WCNSLS CONO: 370040' "$debug" || {
        cat "$debug" >&2
        echo "$tag: red CONO operation missing" >&2
        exit 1
}
grep -Eq 'DATAO 000000123456|WCNSLS DATAIO: DATAO 000000123456' "$debug" || {
        cat "$debug" >&2
        echo "$tag: first DATAO operation missing" >&2
        exit 1
}
grep -Eq 'WCNSLS.*CONO.*003740|WCNSLS CONO: 003740' "$debug" || {
        cat "$debug" >&2
        echo "$tag: green CONO operation missing" >&2
        exit 1
}
grep -Eq 'DATAO 000000321654|WCNSLS DATAIO: DATAO 000000321654' "$debug" || {
        cat "$debug" >&2
        echo "$tag: second DATAO operation missing" >&2
        exit 1
}
grep -Eq 'DATI|DATAI' "$debug" || {
        cat "$debug" >&2
        echo "$tag: raw DATAI operation missing" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (privileged RT raw DATAI/CONO/DATAO userspace path)"
