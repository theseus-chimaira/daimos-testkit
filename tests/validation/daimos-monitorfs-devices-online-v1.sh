#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

simh_pdp6=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}

make_cmd=${MAKE:-make}
tag=daimos-monitorfs-devices-online-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
clean="$work/simh.clean"
ini="$work/runtime.ini"

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$user"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

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
    -S "$self/daimos-monitorfs-devices-online-v1.c" -o "$user/init.s"
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
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot="$build/system/boot/pdp6"

sed '/^go 020$/,$d' "$boot/boot.ini" >"$ini"
cat >>"$ini" <<'EOF'
detach ptp
set ptp disabled
set cr disabled
detach cp
set cp disabled
detach dcs0
set dcs disabled
detach ge0
set ge disabled
detach dtc0
detach dtc1
detach dtc2
set dtc disabled
detach mtc0
detach mtc1
set mtc disabled
set slave disabled
go 020
exit
EOF

set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 20s stdbuf -o0 -e0 \
            "$simh_pdp6" "$ini"
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "MonitorFS device view-online: simulator failed: $rc" >&2
        exit 1
fi
tr -d '\r\n' <"$out" >"$clean"
text=$(cat "$clean")
case "$text" in
*'<'*'H'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "MonitorFS device view-online: target validation did not complete" >&2
        exit 1
        ;;
esac
case "$text" in
*'!'*)
        cat "$out" >&2
        echo "MonitorFS device view-online: target validation failed" >&2
        exit 1
        ;;
esac

printf '%s\n' 'MonitorFS device view-online: PASS (MonitorFS device view mirrors successful MINIT probes)'
