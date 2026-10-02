#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-init-once-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
pty="$work/pty-run"
out="$work/simh.out"
fifo="$work/simh.in"
inittab="$work/inittab"
passwd="$work/passwd"
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

cat >"$inittab" <<'EOT'
MALFORMED
0:ONCE:/SYSTEM/EXEC/LOGIN
EOT
cat >"$passwd" <<'EOT'
ROOT::0:0:/:/SYSTEM/EXEC/DSH
EOT

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$make_cmd" -C "$DAIMOS_REPO/userland" build \
        BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" \
        USERLAND_BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 SYSTEM_INITTAB_TEXT="$inittab" \
        SYSTEM_PASSWD_TEXT="$passwd" >/dev/null
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
        ticks=${3:-500}
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

wait_new 'INIT: BAD INITTAB' 0 || {
        cat "$out" >&2
        echo "$tag: malformed record was not rejected" >&2
        exit 1
}
wait_new 'LOGIN: ' 0 || {
        cat "$out" >&2
        echo "$tag: ONCE entry did not start" >&2
        exit 1
}
start=`log_size`
printf 'ROOT\r' >&3
wait_new 'DSH V1' "$start" || {
        cat "$out" >&2
        echo "$tag: ONCE login did not enter DSH" >&2
        exit 1
}
start=`log_size`
printf 'EXIT\r' >&3
sleep 3
if tail -c "+$((start + 1))" "$out" 2>/dev/null | grep -F 'LOGIN: ' >/dev/null 2>&1; then
        cat "$out" >&2
        echo "$tag: ONCE entry respawned" >&2
        exit 1
fi
kill -0 "$child" 2>/dev/null || {
        cat "$out" >&2
        echo "$tag: INIT did not remain alive after ONCE child exit" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (malformed INITTAB rejected, ONCE not respawned)"
