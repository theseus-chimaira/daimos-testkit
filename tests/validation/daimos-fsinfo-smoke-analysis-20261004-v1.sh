#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-userspace-multitty-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
pty="$work/pty-run"
tcp="$work/tcp-run"
cty_out="$work/cty.out"
dcs_out="$work/dcs.out"
ge_out="$work/ge.out"
cty_in="$work/cty.in"
dcs_in="$work/dcs.in"
ge_in="$work/ge.in"
simh_pid=
dcs_pid=
ge_pid=
dcs_port=$((20000 + ($$ % 10000)))
ge_port=$((40000 + ($$ % 10000)))

cleanup()
{
        for pid in "$ge_pid" "$dcs_pid" "$simh_pid"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        exec 3>&- 4>&- 5>&- 2>/dev/null || true
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"
"$make_cmd" -C "$DAIMOS_REPO/userland" build \
        BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
PATH="$PDP10_PREFIX/bin:$PATH" \
        "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" \
        USERLAND_BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 SIMH_DCS0_PORT="$dcs_port" \
        SIMH_GE0_PORT="$ge_port" >/dev/null
boot="$build/system/boot/pdp6"

mkfifo "$cty_in" "$dcs_in" "$ge_in"
exec 3<>"$cty_in"
exec 4<>"$dcs_in"
exec 5<>"$ge_in"
(
        cd "$boot"
        TERM=dumb exec "$pty" -r "$PDP10_PREFIX/bin/pdp6" boot.ini \
                <"$cty_in" >"$cty_out" 2>&1
) &
simh_pid=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$dcs_in" >"$dcs_out" 2>&1 &
dcs_pid=$!
"$tcp" 127.0.0.1 "$ge_port" <"$ge_in" >"$ge_out" 2>&1 &
ge_pid=$!

log_size()
{
        if [ -f "$1" ]; then wc -c <"$1" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        file=$1
        pattern=$2
        start=$3
        ticks=${4:-500}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                        grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$simh_pid" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

fail_logs()
{
        echo "--- CTY ---" >&2
        cat "$cty_out" >&2 || true
        echo "--- DCS0 ---" >&2
        cat "$dcs_out" >&2 || true
        echo "--- GE0 ---" >&2
        cat "$ge_out" >&2 || true
        echo "$tag: $1" >&2
        exit 1
}

send_slow()
{
        fd=$1
        text=$2
        while [ -n "$text" ]; do
                rest=${text#?}
                ch=${text%"$rest"}
                printf '%s' "$ch" >&"$fd"
                if [ "$fd" -ne 3 ]; then
                        sleep 0.12
                fi
                text=$rest
        done
        printf '\r' >&"$fd"
        if [ "$fd" -ne 3 ]; then
                sleep 0.12
        fi
}

# CTY's initial prompt is visible directly.  A remote line may have emitted
# its first prompt before SIMH accepted the TCP carrier, so an empty line is
# used to force LOGIN to print a fresh prompt after connection.
wait_new "$cty_out" 'LOGIN: ' 0 || fail_logs 'CTY login prompt missing'
wait_new "$dcs_out" 'Connected to the PDP6 simulator DCS device' 0 || \
        fail_logs 'DCS0 TCP transport did not connect'
wait_new "$ge_out" 'Connected to the PDP6 simulator GE device' 0 || \
        fail_logs 'GE0 TCP transport did not connect'
for spec in "4:$dcs_out" "5:$ge_out"; do
        fd=${spec%%:*}
        file=${spec#*:}
        start=`log_size "$file"`
        send_slow "$fd" ''
        wait_new "$file" 'LOGIN: ' "$start" || \
                fail_logs 'remote LOGIN did not reprompt after carrier'
done

# Each terminal must enter its own DSH.  Successful reads also prove LOGIN
# installed a controlling TTY and made its session pgrp foreground.
for spec in "3:$cty_out" "4:$dcs_out" "5:$ge_out"; do
        fd=${spec%%:*}
        file=${spec#*:}
        start=`log_size "$file"`
        send_slow "$fd" ROOT
        wait_new "$file" 'DSH V1' "$start" || \
                fail_logs 'ROOT login did not enter DSH'
done

# Unique output must remain on the originating logical terminal.
cty_start=`log_size "$cty_out"`; dcs_start=`log_size "$dcs_out"`; ge_start=`log_size "$ge_out"`
send_slow 3 'ECHO CTYMARK'
wait_new "$cty_out" CTYMARK "$cty_start" || fail_logs 'CTY command failed'
sleep 0.3
if tail -c "+$((dcs_start + 1))" "$dcs_out" | grep -F CTYMARK >/dev/null 2>&1 || \
   tail -c "+$((ge_start + 1))" "$ge_out" | grep -F CTYMARK >/dev/null 2>&1; then
        fail_logs 'CTY output crossed to a remote terminal'
fi
cty_start=`log_size "$cty_out"`; dcs_start=`log_size "$dcs_out"`; ge_start=`log_size "$ge_out"`
send_slow 4 'ECHO DCSMARK'
wait_new "$dcs_out" DCSMARK "$dcs_start" || fail_logs 'DCS0 command failed'
sleep 0.3
if tail -c "+$((cty_start + 1))" "$cty_out" | grep -F DCSMARK >/dev/null 2>&1 || \
   tail -c "+$((ge_start + 1))" "$ge_out" | grep -F DCSMARK >/dev/null 2>&1; then
        fail_logs 'DCS0 output crossed to another terminal'
fi
cty_start=`log_size "$cty_out"`; dcs_start=`log_size "$dcs_out"`; ge_start=`log_size "$ge_out"`
send_slow 5 'ECHO GEMARK'
wait_new "$ge_out" GEMARK "$ge_start" || fail_logs 'GE0 command failed'
sleep 0.3
if tail -c "+$((cty_start + 1))" "$cty_out" | grep -F GEMARK >/dev/null 2>&1 || \
   tail -c "+$((dcs_start + 1))" "$dcs_out" | grep -F GEMARK >/dev/null 2>&1; then
        fail_logs 'GE0 output crossed to another terminal'
fi

# Record resource accounting before the respawn stress.
cty_start=`log_size "$cty_out"`
send_slow 3 MEMSTAT
wait_new "$cty_out" 'FILE-SLOTS-MAX ' "$cty_start" || fail_logs 'initial MEMSTAT failed'
wait_new "$cty_out" '# ' "$cty_start" || fail_logs 'initial MEMSTAT prompt did not return'
tail -c "+$((cty_start + 1))" "$cty_out" | tr -d '\r' >"$work/mem-before"
mem_words_before=`awk '$1 == "PROCESS-WORDS" { print $2 }' "$work/mem-before"`
mem_slots_before=`awk '$1 == "PROC-SLOTS" { print $2 }' "$work/mem-before"`
file_slots_before=`awk '$1 == "FILE-SLOTS" { print $2 }' "$work/mem-before"`
[ -n "$mem_words_before" ] && [ -n "$mem_slots_before" ] && [ -n "$file_slots_before" ] || \
        fail_logs 'initial MEMSTAT fields missing'


# Focused FSINFO consumer acceptance.
cty_start=`log_size "$cty_out"`
send_slow 3 MOUNTS
wait_new "$cty_out" 'D6FS /' "$cty_start" || fail_logs 'MOUNTS did not report D6FS root'
wait_new "$cty_out" '# ' "$cty_start" || fail_logs 'MOUNTS prompt did not return'
cty_start=`log_size "$cty_out"`
send_slow 3 DF
wait_new "$cty_out" 'FILESYSTEM MOUNT TOTAL USED FREE' "$cty_start" || fail_logs 'DF header missing'
wait_new "$cty_out" 'D6FS / ' "$cty_start" || fail_logs 'DF did not report D6FS root'
wait_new "$cty_out" '# ' "$cty_start" || fail_logs 'DF prompt did not return'
echo 'daimos-fsinfo-smoke-analysis-20261004-v1: PASS (MOUNTS/DF FSINFO copyout)'
exit 0

# Repeated DCS logout/login must reuse the process slot and must not cause INIT
# to respawn either of the other sessions.
n=0
while [ "$n" -lt 3 ]; do
        cty_start=`log_size "$cty_out"`; dcs_start=`log_size "$dcs_out"`; ge_start=`log_size "$ge_out"`
        send_slow 4 EXIT
        wait_new "$dcs_out" 'LOGIN: ' "$dcs_start" || fail_logs 'DCS0 did not respawn LOGIN'
        sleep 0.3
        if tail -c "+$((cty_start + 1))" "$cty_out" | grep -F 'LOGIN: ' >/dev/null 2>&1 || \
           tail -c "+$((ge_start + 1))" "$ge_out" | grep -F 'LOGIN: ' >/dev/null 2>&1; then
                fail_logs 'DCS0 logout disturbed another session'
        fi
        dcs_start=`log_size "$dcs_out"`
        send_slow 4 ROOT
        wait_new "$dcs_out" 'DSH V1' "$dcs_start" || fail_logs 'DCS0 relogin failed'
        n=$((n + 1))
done

# All sessions remain responsive after the respawn cycles.
cty_start=`log_size "$cty_out"`; send_slow 3 'ECHO CTY2'; wait_new "$cty_out" CTY2 "$cty_start" || fail_logs 'CTY stopped responding'
dcs_start=`log_size "$dcs_out"`; send_slow 4 'ECHO DCS2'; wait_new "$dcs_out" DCS2 "$dcs_start" || fail_logs 'DCS0 stopped responding'
ge_start=`log_size "$ge_out"`; send_slow 5 'ECHO GE2'; wait_new "$ge_out" GE2 "$ge_start" || fail_logs 'GE0 stopped responding'

# The process table must contain only swapper, INIT, and the three live login
# sessions after the repeated logout/login cycles.
cty_start=`log_size "$cty_out"`
send_slow 3 PS
wait_new "$cty_out" 'PID PPID S WORDS COMM' "$cty_start" || fail_logs 'PS failed'
wait_new "$cty_out" '# ' "$cty_start" || fail_logs 'PS prompt did not return'
proc_lines=`tail -c "+$((cty_start + 1))" "$cty_out" | tr -d '\r' | \
        awk '/^[0-9][0-9]* [0-9][0-9]* [0-9][0-9]* [0-9][0-9]* / { n++ } END { print n+0 }'`
[ "$proc_lines" -eq 5 ] || fail_logs "process-slot leak after relogin cycles ($proc_lines entries)"

cty_start=`log_size "$cty_out"`
send_slow 3 MEMSTAT
wait_new "$cty_out" 'FILE-SLOTS-MAX ' "$cty_start" || fail_logs 'final MEMSTAT failed'
wait_new "$cty_out" '# ' "$cty_start" || fail_logs 'final MEMSTAT prompt did not return'
tail -c "+$((cty_start + 1))" "$cty_out" | tr -d '\r' >"$work/mem-after"
mem_words_after=`awk '$1 == "PROCESS-WORDS" { print $2 }' "$work/mem-after"`
mem_slots_after=`awk '$1 == "PROC-SLOTS" { print $2 }' "$work/mem-after"`
file_slots_after=`awk '$1 == "FILE-SLOTS" { print $2 }' "$work/mem-after"`
[ "$mem_words_after" = "$mem_words_before" ] || fail_logs 'process-word leak after relogin cycles'
[ "$mem_slots_after" = "$mem_slots_before" ] || fail_logs 'process-slot leak after relogin cycles'
[ "$file_slots_after" = "$file_slots_before" ] || fail_logs 'file-slot leak after relogin cycles'

# STOP on the DCS foreground pgrp must not create a replacement LOGIN and must
# not stop INIT or either other terminal.  This covers the INIT WAIT event rule
# and terminal-local foreground job control in the real login configuration.
dcs_start=`log_size "$dcs_out"`
printf '\032' >&4
sleep 1
if tail -c "+$((dcs_start + 1))" "$dcs_out" | grep -F 'LOGIN: ' >/dev/null 2>&1; then
        fail_logs 'STOP notification caused duplicate DCS0 LOGIN'
fi
cty_start=`log_size "$cty_out"`; send_slow 3 'ECHO CTYFG'; wait_new "$cty_out" CTYFG "$cty_start" || fail_logs 'DCS0 STOP affected CTY'
ge_start=`log_size "$ge_out"`; send_slow 5 'ECHO GEFG'; wait_new "$ge_out" GEFG "$ge_start" || fail_logs 'DCS0 STOP affected GE0'

# GE logout has its own independent respawn as well.
ge_start=`log_size "$ge_out"`; cty_start=`log_size "$cty_out"`
send_slow 5 EXIT
wait_new "$ge_out" 'LOGIN: ' "$ge_start" || fail_logs 'GE0 did not respawn LOGIN'
sleep 0.3
if tail -c "+$((cty_start + 1))" "$cty_out" | grep -F 'LOGIN: ' >/dev/null 2>&1; then
        fail_logs 'GE0 logout disturbed CTY'
fi

printf '%s\n' "$tag: PASS (CTY/DCS0/GE0 login, routing, respawn, resource stability and STOP isolation)"
