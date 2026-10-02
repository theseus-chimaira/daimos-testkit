#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-userspace-bootstrap-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
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
mkdir -p "$work"

"$make_cmd" -C "$DAIMOS_REPO/userland" build \
        BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
for image in init.dxr login.dxr dsh.dxr; do
        test -s "$build/userland/$image" || {
                echo "$tag: missing distinct userspace image $image" >&2
                exit 1
        }
done

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
PATH="$PDP10_PREFIX/bin:$PATH" \
        "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" \
        USERLAND_BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 >/dev/null
boot="$build/system/boot/pdp6"

python3 - "$build/userland/login.dxr" "$build/userland/login.d6lz.dxr" \
    "$build/userland/dsh.dxr" "$build/userland/dsh.d6lz.dxr" <<'PYCOMP'
import os, struct, sys
F_COMPRESSED = 0o100000
pairs = ((sys.argv[1], sys.argv[2], 'LOGIN'),
         (sys.argv[3], sys.argv[4], 'DSH'))
for plain, comp, name in pairs:
    if not os.path.isfile(comp):
        raise SystemExit('%s compressed DXR missing' % name)
    if os.path.getsize(comp) >= os.path.getsize(plain):
        raise SystemExit('%s compressed DXR did not shrink' % name)
    data = open(comp, 'rb').read(16)
    if len(data) != 16:
        raise SystemExit('%s compressed DXR header truncated' % name)
    word1 = struct.unpack_from('<Q', data, 8)[0]
    if (word1 & F_COMPRESSED) == 0:
        raise SystemExit('%s compressed flag missing' % name)
PYCOMP

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
        ticks=${3:-400}
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
printf 'ROOT\r' >&3
wait_new 'DSH V1' "$start" || {
        cat "$out" >&2
        echo "$tag: empty-password ROOT login did not exec DSH" >&2
        exit 1
}
start=`log_size`
printf 'EXIT\r' >&3
wait_new 'LOGIN: ' "$start" || {
        cat "$out" >&2
        echo "$tag: INIT did not reap and respawn LOGIN" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (compressed LOGIN/DSH, INIT -> LOGIN -> DSH and respawn)"
