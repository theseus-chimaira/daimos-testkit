#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-date-login-v597
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
0:RESPAWN:/SYSTEM/EXEC/LOGIN
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
sed -i "s/^set pclk enabled$/set pclk disabled/" "$boot/boot.ini"

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

wait_new 'LOGIN: ' 0 || {
        cat "$out" >&2
        echo "$tag: LOGIN prompt missing" >&2
        exit 1
}
start=$(log_size)
printf 'ROOT\r' >&3
wait_new 'UTC (YYYY-MM-DD HH:MM:SS): ' "$start" || {
        cat "$out" >&2
        echo "$tag: unset clock did not prompt via DATE" >&2
        exit 1
}
start=$(log_size)
printf '2026-10-28 13:42:05\r' >&3
wait_new 'DSH V1' "$start" || {
        cat "$out" >&2
        echo "$tag: successful DATE did not continue to shell" >&2
        exit 1
}
start=$(log_size)
printf 'DATE\r' >&3
wait_new '2026-10-28 13:42:' "$start" || {
        cat "$out" >&2
        echo "$tag: DATE did not preserve configured UTC" >&2
        exit 1
}
printf '%s\n' "$tag: PASS (unset clock prompts DATE at privileged login)"
