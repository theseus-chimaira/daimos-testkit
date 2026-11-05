#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-group-self-fatal-v979
e08=${V1155_E08:-0}
case "$e08" in
    0|1) ;;
    *) echo 'v1155: invalid E08 mode' >&2; exit 2 ;;
esac
if [ "$e08" = 1 ]; then tag=daimos-oom-groups-sessions-v1155; fi
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

cleanup()
{
        if [ "${KEEP_TEST:-0}" != 1 ]; then
                rm -rf "$work"
        else
                printf 'v1155: retained guest and logs at %s\n' "$work"
        fi
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

"$cc" -std=c89 -Os -DV1155_E08="$e08" \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-group-self-fatal-v979.c" \
    -o "$user/init.s"
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

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" \
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

boot="$build/system/boot/pdp6"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
set +e
guest_timeout=30s
if [ "$e08" = 1 ]; then guest_timeout=240s; fi
(
        cd "$boot"
        TERM=dumb timeout -k 2s "$guest_timeout" stdbuf -o0 -e0 \
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
*'<'*) text=${text#*<} ;;
*)
        cat "$out" >&2
        echo "$tag: event sentinel missing" >&2
        exit 1
        ;;
esac
case "$text" in
*'!'*|*'X'*)
        cat "$out" >&2
        echo "$tag: target event test reported failure" >&2
        exit 1
        ;;
esac
case "$text" in
*'0abcdefgJE'*'HALT'*) [ "$e08" = 1 ] ;;
*'E'*'HALT'*) [ "$e08" = 0 ] ;;
*)
        cat "$out" >&2
        echo "$tag: event completion/HALT missing" >&2
        exit 1
        ;;
esac

if [ "$e08" = 1 ]; then
    echo "$tag: PASS (two live foreign sessions, two concurrent 2-member groups, STOP/CONT/CHLD/WAIT, 64 PID lifetimes and stale-event exclusion)"
else
    echo "$tag: PASS (PID/PGRP events, TSTP/CONT, CHLD, fatal-event WAIT status, pending ALRM)"
fi
