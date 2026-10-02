#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
: "${PTY_RUN:?PTY_RUN must be set}"
: "${TCP_RUN:?TCP_RUN must be set}"

tag=daimos-monitorfs-live-state-v1
work=$TMPDIR/$tag-$$
build=$work/build
run=$work/run
inittab=$work/inittab
fifo=$run/dcs.in
dcs=$run/dcs.log
cty=$run/cty.log
dcs_port=$((25000 + ($$ % 1000)))
ge_port=$((dcs_port + 12000))
sim_pid=
tcp_pid=

cleanup()
{
        if [ -n "$tcp_pid" ] && kill -0 "$tcp_pid" 2>/dev/null; then
                kill "$tcp_pid" 2>/dev/null || true
                wait "$tcp_pid" 2>/dev/null || true
        fi
        if [ -n "$sim_pid" ] && kill -0 "$sim_pid" 2>/dev/null; then
                kill "$sim_pid" 2>/dev/null || true
                wait "$sim_pid" 2>/dev/null || true
        fi
        exec 3>&- 2>/dev/null || true
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$run"
printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/LOGIN' > "$inittab"

log_size()
{
        if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        file=$1
        marker=$2
        start=$3
        ticks=${4:-1200}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                    grep -F "$marker" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$sim_pid" 2>/dev/null || return 1
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
                printf '%s' "$ch" >&3
                sleep 0.08
                text=$rest
        done
        printf '\r' >&3
        sleep 0.15
}

fail()
{
        echo '--- CTY ---' >&2
        cat "$cty" >&2 || true
        echo '--- DCS0 ---' >&2
        cat "$dcs" >&2 || true
        echo "$tag: $1" >&2
        exit 1
}

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    SYSTEM_INITTAB_TEXT="$inittab" SIMH_DCS0_PORT="$dcs_port" \
    SIMH_GE0_PORT="$ge_port" >/dev/null

mkfifo "$fifo"
exec 3<>"$fifo"
(
        cd "$DAIMOS_REPO"
        TERM=dumb exec "$PTY_RUN" "$PDP10_PREFIX/bin/pdp6" "$build/boot.ini" </dev/null
) >"$cty" 2>&1 &
sim_pid=$!
"$TCP_RUN" 127.0.0.1 "$dcs_port" <"$fifo" >"$dcs" 2>&1 &
tcp_pid=$!

wait_new "$dcs" 'Connected to the PDP6 simulator DCS device' 0 600 || \
    fail 'DCS0 transport missing'
start=`log_size "$dcs"`
send_slow ''
wait_new "$dcs" 'LOGIN: ' "$start" 1200 || fail 'LOGIN prompt missing'

# Lowercase input must be normalized before echo and before LOGIN sees it.
start=`log_size "$dcs"`
send_slow root
wait_new "$dcs" 'DSH V1' "$start" 1800 || fail 'lowercase root login failed'
segment=$work/login.segment
tail -c "+$((start + 1))" "$dcs" | tr -d '\r' > "$segment"
grep -F ROOT "$segment" >/dev/null 2>&1 || fail 'username was not echoed uppercase'
if grep -F root "$segment" >/dev/null 2>&1; then
        fail 'lowercase username leaked through cooked echo'
fi

# The complete command is lowercase.  Successful lookup proves cooked SIXBIT
# normalization applies systemwide, not only inside LOGIN.
start=`log_size "$dcs"`
send_slow 'cd /monitor/processes/2'
wait_new "$dcs" '# ' "$start" 800 || fail 'cd into process directory failed'
start=`log_size "$dcs"`
send_slow 'cd ..'
wait_new "$dcs" '# ' "$start" 800 || fail 'cd .. from process directory failed'
start=`log_size "$dcs"`
send_slow 'cat 2/name'
wait_new "$dcs" 'DSH' "$start" 800 || \
    fail 'cd .. did not return to process root'
wait_new "$dcs" '# ' "$start" 800 || fail 'relative process read did not return'

start=`log_size "$dcs"`
send_slow 'cat /monitor/processes/2/name'
wait_new "$dcs" 'DSH' "$start" 800 || fail 'NAME leaf did not expose DSH'
wait_new "$dcs" '# ' "$start" 800 || fail 'NAME command did not return'
tail -c "+$((start + 1))" "$dcs" | grep -F 'CAT /MONITOR/PROCESSES/2/NAME' \
    >/dev/null 2>&1 || fail 'lowercase command/path was not echoed uppercase'

start=`log_size "$dcs"`
send_slow 'cat /monitor/processes/2/cmdline'
wait_new "$dcs" '/SYSTEM/EXEC/DSH' "$start" 800 || \
    fail 'CMDLINE did not reconstruct DSH argv'

start=`log_size "$dcs"`
send_slow 'cat /monitor/processes/2/environment'
wait_new "$dcs" 'HOME=/' "$start" 800 || fail 'ENVIRONMENT missing HOME'
wait_new "$dcs" 'USER=ROOT' "$start" 800 || fail 'ENVIRONMENT missing USER'
wait_new "$dcs" 'SHELL=/SYSTEM/EXEC/DSH' "$start" 800 || \
    fail 'ENVIRONMENT missing SHELL'

# PID 1 now uses the same image-startup metadata as RUN/EXEC processes.
start=`log_size "$dcs"`
send_slow 'cat /monitor/processes/1/name'
wait_new "$dcs" 'INIT' "$start" 800 || fail 'PID 1 NAME is not INIT'
start=`log_size "$dcs"`
send_slow 'cat /monitor/processes/1/cmdline'
wait_new "$dcs" '/SYSTEM/INIT' "$start" 800 || fail 'PID 1 CMDLINE missing'

# Domain 1 owns INIT and the sole DCS login shell.  PIDS is derived by scanning
# the process table; no persistent membership table exists.
for leaf in processes words swapped swapwords stopped pids; do
        start=`log_size "$dcs"`
        send_slow "cat /monitor/domains/1/$leaf"
        wait_new "$dcs" '# ' "$start" 800 || fail "domain $leaf leaf unreadable"
        if tail -c "+$((start + 1))" "$dcs" | grep -F 'CAT:' >/dev/null 2>&1; then
                fail "domain $leaf leaf failed"
        fi
done
clean=$work/dcs.clean
tr -d '\r' < "$dcs" > "$clean"
grep -F '001' "$clean" >/dev/null 2>&1 || fail 'PIDS missing INIT'
grep -F '002' "$clean" >/dev/null 2>&1 || fail 'PIDS missing DSH'

printf '%s\n' "$tag: PASS (systemwide cooked SIXBIT, NAME/CMDLINE/ENVIRONMENT, derived domain leaves/PIDS)"
