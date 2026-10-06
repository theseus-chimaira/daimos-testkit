#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-apr-injected-fault-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
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
    -S "$self/daimos-apr-injected-fault-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$das" -C -F -O "$user/pdl.dobj" "$self/daimos-apr-pdl-overflow-v1.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" \
    "$user/pdl.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot="$build/system/boot/pdp6"

run_case()
{
        name=$1
        reg=$2
        ini="$work/$name.ini"
        out="$work/$name.out"
        dcs_port=$((31000 + ($$ % 9000)))
        ge_port=$((41000 + ($$ % 9000)))

        "$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
            "$ini.base" "$dcs_port" "$ge_port"
        sed "/^go 020$/i expect \"<\" deposit cpu $reg 1; continue" \
            "$ini.base" >"$ini"

        set +e
        (
                cd "$boot"
                TERM=dumb timeout -k 2s 20s stdbuf -o0 -e0 \
                    "$PDP10_PREFIX/bin/pdp6" "$ini"
        ) >"$out" 2>&1
        rc=$?
        set -e
        if [ "$rc" -ne 0 ]; then
                cat "$out" >&2
                echo "$tag: $name did not terminate after injected APR fault" >&2
                exit 1
        fi
        text=$(tr -d '\r\n' <"$out")
        case "$text" in
        *'<'*'HALT'*) ;;
        *)
                cat "$out" >&2
                echo "$tag: $name did not reach fault termination/HALT" >&2
                exit 1
                ;;
        esac
}

run_case nxm NXM
printf '%s\n' "$tag: NXM PASS"

# A second boot uses two boot users.  Slot 2 executes a real overflowing PUSH;
# slot 1 remains available so correct fault delivery can reap slot 2 without
# making the machine's final-user HALT ambiguous with an executive fault HALT.
PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$work/pdl-build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=2 \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
pdl_boot="$work/pdl-build/system/boot/pdp6"
pdl_ini="$work/pdl.ini"
pdl_out="$work/pdl.out"
dcs_port=$((32000 + ($$ % 8000)))
ge_port=$((42000 + ($$ % 8000)))
"$self/../lib/daimos-simh-headless.sh" "$pdl_boot/boot.ini" \
    "$pdl_ini" "$dcs_port" "$ge_port"

set +e
(
        cd "$pdl_boot"
        TERM=dumb timeout -k 2s 5s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" "$pdl_ini"
) >"$pdl_out" 2>&1
rc=$?
set -e

# Slot 1 spins, so timeout is expected.  What matters is that slot 2's real
# PUSH overflow neither prints ! nor wedges the simulator in a PI6 storm.
if [ "$rc" -ne 124 ]; then
        cat "$pdl_out" >&2
        echo "$tag: unexpected simulator result in PDL case: $rc" >&2
        exit 1
fi
text=$(tr -d '\r\n' <"$pdl_out")
case "$text" in
*'!'*)
        cat "$pdl_out" >&2
        echo "$tag: overflowing user PUSH returned instead of faulting" >&2
        exit 1
        ;;
esac

printf '%s\n' "$tag: PASS (SIMH NXM injection and real user PDL overflow delivered)"
