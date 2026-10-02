#!/bin/sh
set -eu

tag=daimos-idle-stack-watermark-v1
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
work="$TMPDIR/$tag-$$"
build="$work/build"
pty="$work/pty-run"
tcp="$work/tcp-run"
cty_log="$work/cty.log"
dcs_log="$work/dcs.log"
cty_fifo="$work/cty.in"
dcs_fifo="$work/dcs.in"
child=
dcs_child=
dcs_port=$((25000 + ($$ % 7000)))
ge_port=$((42000 + ($$ % 7000)))

cleanup()
{
        for pid in "$dcs_child" "$child"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        exec 3>&- 4>&- 2>/dev/null || true
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "`dirname "$0"`/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "`dirname "$0"`/../../tools/tcp-run-v1.c"
PATH="$PDP10_PREFIX/bin:$PATH" "$make_cmd" \
        -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_STACK_WATERMARK=1 SIMH_DCS0_PORT="$dcs_port" \
        SIMH_GE0_PORT="$ge_port" >/dev/null

addr=`awk '$1 == "kernel_idle_stack_highwater" { print $2 }' "$build/kcore.map"`
[ -n "$addr" ] || {
        echo "$tag: kernel_idle_stack_highwater missing from instrumented map" >&2
        exit 1
}

sed -e '/^exit$/d' "$build/boot.ini" > "$work/boot.ini"

mkfifo "$cty_fifo" "$dcs_fifo"
exec 3<>"$cty_fifo"
exec 4<>"$dcs_fifo"
(
        cd "$DAIMOS_REPO"
        exec "$pty" -r "$PDP10_PREFIX/bin/pdp6" "$work/boot.ini" \
                <"$cty_fifo" >"$cty_log" 2>&1
) &
child=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$dcs_fifo" >"$dcs_log" 2>&1 &
dcs_child=$!

log_size()
{
        if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        file=$1
        pattern=$2
        start=$3
        ticks=$4
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                        grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$child" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

send_slow()
{
        text=$1
        while [ -n "$text" ]; do
                rest=${text#?}
                ch=${text%"$rest"}
                printf '%s' "$ch" >&4
                sleep 0.08
                text=$rest
        done
        printf '\r' >&4
        sleep 0.15
}

wait_new "$dcs_log" 'Connected to the PDP6 simulator DCS device' 0 300 || {
        echo "$tag: DCS0 transport did not connect" >&2
        tail -120 "$cty_log" >&2 || true
        tail -120 "$dcs_log" >&2 || true
        exit 1
}
start=`log_size "$dcs_log"`
send_slow ''
wait_new "$dcs_log" 'LOGIN: ' "$start" 600 || {
        echo "$tag: DCS0 LOGIN prompt not reached" >&2
        tail -120 "$dcs_log" >&2 || true
        exit 1
}
start=`log_size "$dcs_log"`
send_slow ROOT
wait_new "$dcs_log" '# ' "$start" 600 || {
        echo "$tag: ROOT login did not reach DSH" >&2
        tail -120 "$dcs_log" >&2 || true
        exit 1
}

# Exercise normal runtime idle/scheduler use before sampling the permanent
# idle-stack watermark.  Current INIT keeps login services alive after shell
# logout, so normal DSH EXIT no longer means final-process HALT.
for cmd in \
        'MEMSTAT' \
        'LS /' \
        'PS' \
        'ECHO AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA > /TEMP/WM' \
        'ECHO BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB >> /TEMP/WM' \
        'CAT /TEMP/WM' \
        'STAT /TEMP/WM' \
        'LS /TEMP'
do
        start=`log_size "$dcs_log"`
        send_slow "$cmd"
        wait_new "$dcs_log" '# ' "$start" 300 || {
                echo "$tag: command did not return: $cmd" >&2
                tail -100 "$dcs_log" >&2 || true
                exit 1
        }
done

# Let at least one clock tick observe an idle interval, then stop SIMH from
# the CTY control channel without perturbing the DCS login/session contract.
sleep 1
start=`log_size "$cty_log"`
printf '\005' >&3
wait_new "$cty_log" 'sim> ' "$start" 100 || {
        echo "$tag: simulator prompt not reached for watermark read" >&2
        tail -100 "$cty_log" >&2 || true
        exit 1
}
start=`log_size "$cty_log"`
printf 'ex %s\n' "$addr" >&3
wait_new "$cty_log" 'sim> ' "$start" 100 || exit 1
value=`tail -c "+$((start + 1))" "$cty_log" | \
        sed -n 's/^[0-7][0-7]*:[[:space:]]*0*\([0-7][0-7]*\).*/\1/p' | tail -1`
[ -n "$value" ] || {
        echo "$tag: could not read idle stack watermark" >&2
        tail -40 "$cty_log" >&2 || true
        exit 1
}
used=$((0$value))
limit=$((00060))
[ "$used" -le "$limit" ] || {
        echo "$tag: kernel idle stack highwater 0$value exceeds 0060" >&2
        exit 1
}
printf '%s\n' "$tag: PASS (highwater=0$value octal words, limit=0060)"
