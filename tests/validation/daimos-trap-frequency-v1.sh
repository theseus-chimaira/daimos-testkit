#!/bin/sh
set -eu

tag=daimos-trap-frequency-v1
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
initial=1000000
child=
dcs_child=
dcs_port=$((26000 + ($$ % 6000)))
ge_port=$((42000 + ($$ % 6000)))

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
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

trap_addr=`awk '$1 == "mach_syscall" { print $2 }' "$build/kcore.map"`
[ -n "$trap_addr" ] || {
        echo "$tag: mach_syscall missing from KCORE map" >&2
        exit 1
}

# Count at the normal fetched instruction after the PDP-6 hardware UUO cycle.
# A large SIMH breakpoint pass count decrements on every syscall without
# stopping the guest.  We enter the simulator prompt only between workloads.
sed -e "/^go 020$/i\\break $trap_addr[$initial]" \
    -e '/^exit$/d' \
    "$build/boot.ini" > "$work/boot.ini"

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
        if [ -f "$1" ]; then
                wc -c < "$1" | tr -d ' '
        else
                echo 0
        fi
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

stop_count()
{
        start=`log_size "$cty_log"`
        printf '\005' >&3
        wait_new "$cty_log" 'sim> ' "$start" 100 || return 1
        start=`log_size "$cty_log"`
        printf 'show break\n' >&3
        wait_new "$cty_log" 'sim> ' "$start" 100 || return 1
        tail -c "+$((start + 1))" "$cty_log" | \
                sed -n 's/.*E\[\([0-9][0-9]*\)\].*/\1/p' | tail -1
}

resume_guest()
{
        printf 'continue\n' >&3
        sleep 0.2
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

send_text_slow()
{
        text=$1
        while [ -n "$text" ]; do
                rest=${text#?}
                ch=${text%"$rest"}
                printf '%s' "$ch" >&4
                sleep 0.08
                text=$rest
        done
}

run_command()
{
        text=$1
        # DCS input itself crosses the monitor path once or more per typed
        # character.  That transport cost is not part of this test's command
        # syscall-frequency budget.  Type the command first while DSH is
        # blocked waiting for the terminating CR, then take a fresh breakpoint
        # baseline and count only CR handling plus command execution.
        resume_guest
        send_text_slow "$text"
        before=`stop_count`
        resume_guest
        start=`log_size "$dcs_log"`
        printf '\r' >&4
        sleep 0.15
        wait_new "$dcs_log" '# ' "$start" 300 || {
                echo "$tag: command did not return to DSH: $text" >&2
                tail -80 "$dcs_log" >&2 || true
                return 1
        }
        after=`stop_count`
        echo $((before - after))
}

assert_max()
{
        name=$1
        value=$2
        limit=$3
        if [ "$value" -gt "$limit" ]; then
                echo "$tag: $name trap regression: $value > $limit" >&2
                exit 1
        fi
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
prev=`stop_count`
startup=$((initial - prev))

# Authentication/session setup is not part of the command syscall-frequency
# budget.  Resume, log in through the reliable DCS path, then reset the
# baseline after DSH has printed its first prompt.
resume_guest
start=`log_size "$dcs_log"`
send_slow ROOT
wait_new "$dcs_log" '# ' "$start" 600 || {
        echo "$tag: ROOT login did not reach DSH" >&2
        tail -120 "$dcs_log" >&2 || true
        exit 1
}
prev=`stop_count`

enter_traps=`run_command ''`

raw=`run_command 'ECHO HELLO'`
echo_traps=$((raw - enter_traps))

raw=`run_command 'MEMSTAT'`
memstat_traps=$((raw - enter_traps))

raw=`run_command 'LS /'`
ls_traps=$((raw - enter_traps))

raw=`run_command 'PS'`
ps_traps=$((raw - enter_traps))

# Build a 128-character regular file as four 30-character lines plus CRLF.
# Setup traffic is intentionally excluded from the CAT measurement.
payload=`printf '%30s' '' | tr ' ' A`
for redir in '>' '>>' '>>' '>>'; do
        run_command "ECHO $payload $redir /TEMP/TKCAT" >/dev/null
done
raw=`run_command 'CAT /TEMP/TKCAT'`
cat_traps=$((raw - enter_traps))

# Startup now includes asynchronous INIT + LOGIN service activity through the
# first DCS login prompt, so its exact count depends on host scheduling around
# the prompt.  Keep only a coarse runaway guard here; the deterministic DSH
# command deltas below retain the tight syscall-regression budgets.
assert_max startup "$startup" 128
assert_max echo "$echo_traps" 35
assert_max memstat "$memstat_traps" 70
assert_max ls "$ls_traps" 70
assert_max ps "$ps_traps" 110
assert_max cat128 "$cat_traps" 45

printf '%s\n' "$tag: PASS (startup=$startup echo=$echo_traps memstat=$memstat_traps ls=$ls_traps ps=$ps_traps cat128=$cat_traps traps)"
