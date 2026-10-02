#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

host_cc=${HOST_CC:-cc}
tag=daimos-tty-s6rec-input-v1
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
    "$(dirname "$0")/../../tools/pty-run-v1.c"
"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/ipc" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$(dirname "$0")/daimos-tty-s6rec-input-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

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
        i=0
        while [ "$i" -lt 300 ]; do
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

wait_new '<A' 0 || { cat "$out" >&2; echo "$tag: A missing" >&2; exit 1; }
start=`log_size`
printf 'abc\r' >&3
wait_new '<B' "$start" || { cat "$out" >&2; echo "$tag: B missing" >&2; exit 1; }
start=`log_size`
printf 'hello\r' >&3
wait_new '<C' "$start" || { cat "$out" >&2; echo "$tag: C missing" >&2; exit 1; }
start=`log_size`
printf '\r' >&3
wait_new '<D' "$start" || { cat "$out" >&2; echo "$tag: D missing" >&2; exit 1; }
start=`log_size`
printf '\004' >&3
wait_new '<E' "$start" || { cat "$out" >&2; echo "$tag: E missing" >&2; exit 1; }
start=`log_size`
printf 'z\004' >&3
wait_new '<P' "$start" || { cat "$out" >&2; echo "$tag: completion missing" >&2; exit 1; }

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
case "$(tr -d '\r\n' <"$out")" in
*'!'*) cat "$out" >&2; echo "$tag: target failure" >&2; exit 1 ;;
*'P'*'HALT'*) ;;
*) cat "$out" >&2; echo "$tag: HALT missing" >&2; exit 1 ;;
esac
printf '%s\n' "$tag: PASS (cooked S6REC input, retry, empty/^D, RAW rejection)"
