#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-process-tty-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
pty="$work/pty-run"
out="$work/simh.out"
fifo="$work/simh.in"
child=

cleanup()
{
        if [ -n "$child" ] && kill -0 "$child" 2>/dev/null; then
                kill "$child" 2>/dev/null || true
                wait "$child" 2>/dev/null || true
        fi
        exec 3>&- 2>/dev/null || true
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "`dirname "$0"`/../../tools/pty-run-v1.c"
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
    -S "$(dirname "$0")/daimos-process-tty-v1.c" \
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
mkfifo "$fifo"
exec 3<>"$fifo"
(
        cd "$boot"
        TERM=dumb exec "$pty" "$PDP10_PREFIX/bin/pdp6" boot.ini \
                <"$fifo" >"$out" 2>&1
) &
child=$!

log_size()
{
        if [ -f "$out" ]; then
                wc -c < "$out" | tr -d ' '
        else
                echo 0
        fi
}

wait_new()
{
        pattern=$1
        start=$2
        ticks=$3
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$out" 2>/dev/null | \
                        grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$child" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

start=`log_size`
wait_new '<' "$start" 300 || {
        cat "$out" >&2
        echo "$tag: startup sentinel missing" >&2
        exit 1
}
# Keep the original offset: the child can advance from '<' through the Z
# marker before the host loop gets scheduled again.
wait_new '<b12Z' "$start" 300 || {
        cat "$out" >&2
        echo "$tag: Ctrl-Z input point missing" >&2
        exit 1
}
start=`log_size`
printf '\032' >&3
wait_new 'C' "$start" 300 || {
        cat "$out" >&2
        echo "$tag: Ctrl-C input point missing" >&2
        exit 1
}
start=`log_size`
printf '\003' >&3

# The test exits the final user process, so the simulator reaches the kernel
# HALT and exits through boot.ini's HALTAFTER handling.  Bound this phase: a
# lost control character or scheduler regression must fail the test instead of
# hanging the host test runner indefinitely.
wait_new 'HALT' "$start" 300 || {
        cat "$out" >&2
        echo "$tag: Ctrl-C completion/HALT missing" >&2
        exit 1
}
set +e
wait "$child"
rc=$?
set -e
child=
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
        echo "$tag: target sentinel missing" >&2
        exit 1
        ;;
esac
case "$text" in
*'!'*|*'X'*)
        cat "$out" >&2
        echo "$tag: target TTY test reported failure" >&2
        exit 1
        ;;
esac
case "$text" in
*'H'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "$tag: TTY completion/HALT missing" >&2
        exit 1
        ;;
esac

printf '%s\n' "$tag: PASS (controlling TTY, foreground PGRP, BG read stop, Ctrl-Z/CONT, Ctrl-C)"
