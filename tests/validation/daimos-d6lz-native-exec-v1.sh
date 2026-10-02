#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-d6lz-native-exec-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
pty="$work/pty-run"
if [ -n "${P10JOB_RUN_DIR:-}" ]; then
        out="$P10JOB_RUN_DIR/simh.log"
else
        out="$work/simh.out"
fi
fifo="$work/simh.in"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
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
mkdir -p "$work" "$user"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc"

"$make_cmd" -C "$DAIMOS_REPO/userland" build \
        BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$user/u.s"
"$das" -F -C -O "$user/u.dobj" "$user/u.s"
libgcc=$($cc -print-libgcc-file-name)
for part in driver marker; do
        "$cc" -std=c99 -Os $incs -S "$self/daimos-d6lz-native-exec-v1-$part.c" \
                -o "$user/$part.s"
        "$das" -F -C -O "$user/$part.dobj" "$user/$part.s"
        "$dlink" -b 020 -o "$user/$part.dxr" -M "$user/$part.map" \
                "$user/crt0.dobj" "$user/syscall.dobj" "$user/u.dobj" \
                "$user/$part.dobj" "$libgcc"
done

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$self/../../tools/pty-run-v1.c"
PATH="$PDP10_PREFIX/bin:$PATH" \
        "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" \
        USERLAND_BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 SYSTEM_DSH_DXR="$user/driver.dxr" \
        SYSTEM_TSFSPROBE_DXR="$user/marker.dxr" >/dev/null
boot="$build/system/boot/pdp6"

mkfifo "$fifo"
exec 3<>"$fifo"
(
        cd "$boot"
        TERM=dumb exec "$pty" -r "$PDP10_PREFIX/bin/pdp6" boot.ini \
                <"$fifo" >"$out" 2>&1
) &
child=$!

log_size()
{
        if [ -f "$out" ]; then wc -c <"$out" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        pattern=$1
        start=$2
        ticks=${3:-600}
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

start=0
wait_new 'LOGIN: ' "$start" || {
        cat "$out" >&2
        echo "$tag: CTY login prompt missing" >&2
        exit 1
}
start=`log_size`
sleep 0.3
for ch in R O O T; do
        printf '%s' "$ch" >&3
        sleep 0.05
done
printf '\r' >&3
wait_new 'D6LZ-CEXEC-MARKER' "$start" || {
        cat "$out" >&2
        echo "$tag: compressed native marker did not execute" >&2
        exit 1
}
wait_new 'D6LZ-NATIVE-EXEC-PASS' "$start" || {
        cat "$out" >&2
        echo "$tag: native compressor driver did not report PASS" >&2
        exit 1
}
# Reuse the offset captured before ROOT was sent.  INIT can respawn LOGIN in
# the same terminal write burst as the PASS marker, so taking a new offset
# here can race past the prompt we need to verify.
wait_new 'LOGIN: ' "$start" || {
        cat "$out" >&2
        echo "$tag: INIT did not respawn LOGIN after test driver" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (native D6LZ -X -> flagged DXR -> compressed EXEC)"
