#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-login-password-v1
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
TEST:SECRET:1:1:/TEMP:/SYSTEM/EXEC/DSH
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

wait_new 'LOGIN: ' 0 || {
        cat "$out" >&2
        echo "$tag: login prompt missing" >&2
        exit 1
}
start=`log_size`
printf 'TEST\r' >&3
wait_new 'PASSWORD: ' "$start" || {
        cat "$out" >&2
        echo "$tag: nonempty password did not prompt" >&2
        exit 1
}
fail_start=`log_size`
printf 'WRONG\r' >&3
wait_new 'LOGIN INCORRECT' "$fail_start" || {
        cat "$out" >&2
        echo "$tag: wrong password was not rejected generically" >&2
        exit 1
}
case "`tail -c "+$((fail_start + 1))" "$out" 2>/dev/null`" in
*WRONG*)
        cat "$out" >&2
        echo "$tag: password input was echoed" >&2
        exit 1
        ;;
esac
wait_new 'LOGIN: ' "$fail_start" || {
        cat "$out" >&2
        echo "$tag: login did not reprompt after failure" >&2
        exit 1
}
start=`log_size`
printf 'TEST\r' >&3
wait_new 'PASSWORD: ' "$start" || {
        cat "$out" >&2
        echo "$tag: second password prompt missing" >&2
        exit 1
}
start=`log_size`
printf 'SECRET\r' >&3
wait_new 'DSH V1' "$start" || {
        cat "$out" >&2
        echo "$tag: correct password did not enter DSH" >&2
        exit 1
}
case "`tail -c "+$((start + 1))" "$out" 2>/dev/null`" in
*SECRET*)
        cat "$out" >&2
        echo "$tag: correct password was echoed" >&2
        exit 1
        ;;
esac
start=`log_size`
printf 'PWD\r' >&3
wait_new '/TEMP' "$start" || {
        cat "$out" >&2
        echo "$tag: configured home directory was not entered" >&2
        exit 1
}
start=`log_size`
printf 'TOUCH /CONFIG/UID-DROP-CHECK\r' >&3
wait_new 'TOUCH: /CONFIG/UID-DROP-CHECK' "$start" || {
        cat "$out" >&2
        echo "$tag: non-root account retained write privilege" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (password/no-echo, home cwd, UID/GID drop path)"
