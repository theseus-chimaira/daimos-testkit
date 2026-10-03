#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-dsh-foreground-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
pty="$work/pty-run"
tcp="$work/tcp-run"
cty_out="$work/cty.out"
dcs_out="$work/dcs.out"
dcs_in="$work/dcs.in"
simh_pid=
dcs_pid=
dcs_port=$((22000 + ($$ % 9000)))
ge_port=$((42000 + ($$ % 9000)))

cleanup()
{
        for pid in "$dcs_pid" "$simh_pid"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        exec 3>&- 2>/dev/null || true
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"
mkdir -p "$user"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -I"$DAIMOS_REPO/system/kernel/boot" \
        -I"$DAIMOS_REPO/system/kernel/core" \
        -I"$DAIMOS_REPO/system/kernel/drivers" \
        -I"$DAIMOS_REPO/system/kernel/fs" \
        -I"$DAIMOS_REPO/system/kernel/mm" \
        -I"$DAIMOS_REPO/system/kernel/modules" \
        -I"$DAIMOS_REPO/system/kernel/proc" \
        -I"$DAIMOS_REPO/system/kernel/storage" \
        -I"$DAIMOS_REPO/userland/libc" \
        -I"$DAIMOS_REPO/userland/exec" \
        -I"$PDP10_PREFIX/include" \
        -S "$(dirname "$0")/daimos-dsh-foreground-v1.c" \
        -o "$user/dshfgt.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$user/dshfgt.dobj" "$user/dshfgt.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$user/crt0.dobj" \
        "$DAIMOS_REPO/userland/libc/crt0.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$user/syscall.dobj" \
        "$DAIMOS_REPO/userland/libc/syscall.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$user/syscall-helpers.dobj" \
        "$DAIMOS_REPO/userland/libc/syscall_helpers.s"
"$PDP10_PREFIX/bin/dlink" --daimos-uuo-relax -b 020 \
        -o "$user/dshfgt.dxr" -M "$user/dshfgt.map" \
        "$user/crt0.dobj" "$user/syscall.dobj" "$user/syscall-helpers.dobj" \
        "$user/dshfgt.dobj"
"$make_cmd" -C "$DAIMOS_REPO/userland" build \
        BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
PATH="$PDP10_PREFIX/bin:$PATH" \
        "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" USERLAND_BUILD_ROOT="$build" \
        PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
        D6FS_EXTRA_ARGS="-f /SYSTEM/EXEC/DSHFGT:$user/dshfgt.dxr:555:dxr" \
        >/dev/null
boot="$build/system/boot/pdp6"

mkfifo "$dcs_in"
exec 3<>"$dcs_in"
(
        cd "$boot"
        TERM=dumb exec "$pty" -r "$PDP10_PREFIX/bin/pdp6" boot.ini </dev/null
) >"$cty_out" 2>&1 &
simh_pid=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$dcs_in" >"$dcs_out" 2>&1 &
dcs_pid=$!

log_size()
{
        if [ -f "$dcs_out" ]; then wc -c <"$dcs_out" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        pattern=$1
        start=$2
        ticks=${3:-600}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$dcs_out" 2>/dev/null | \
                        grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$simh_pid" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

fail()
{
        echo "--- CTY ---" >&2
        cat "$cty_out" >&2 || true
        echo "--- DCS0 ---" >&2
        cat "$dcs_out" >&2 || true
        echo "$tag: $1" >&2
        exit 1
}

send_line()
{
        printf '%s\r' "$1" >&3
        sleep 0.2
}

wait_new 'Connected to the PDP6 simulator DCS device' 0 || \
        fail 'DCS0 transport did not connect'
start=`log_size`
send_line ''
wait_new 'LOGIN: ' "$start" || fail 'LOGIN prompt missing'
start=`log_size`
send_line ROOT
wait_new 'DSH V1' "$start" || fail 'ROOT login did not enter DSH'
wait_new '# ' "$start" || fail 'initial DSH prompt missing'

# DSH owns raw/no-echo input while editing.  Ctrl-C must cancel only the
# partial shell input record and return a fresh prompt; it must not leak the
# partial text into the next command.
start=`log_size`
printf 'ECHO MUSTNOTRUN' >&3
sleep 0.2
printf '\003' >&3
wait_new '# ' "$start" 100 || fail 'Ctrl-C did not cancel the shell input line'
start=`log_size`
send_line 'ECHO CTRLCOK'
wait_new 'CTRLCOK' "$start" || fail 'shell input remained contaminated after Ctrl-C'
wait_new '# ' "$start" || fail 'prompt missing after Ctrl-C recovery'

# The test-only helper changes the TTY to RAW and stops itself.  DSH must save
# that mode, reclaim foreground ownership, and restore its own RAW editor mode.
start=`log_size`
send_line /SYSTEM/EXEC/DSHFGT
wait_new '# ' "$start" || fail 'shell did not recover after first helper stop'

start=`log_size`
send_line JOBS
wait_new '%1 STOPPED /SYSTEM/EXEC/DSHFGT' "$start" || \
        fail 'stopped foreground helper missing from JOBS'
wait_new '# ' "$start" || fail 'JOBS did not return to shell'

# First FG must restore RAW before CONT.  The helper verifies foreground pgrp
# and mode, prints FGRAWOK, changes to COOKED, and stops itself again.
start=`log_size`
send_line FG
wait_new 'FGRAWOK' "$start" || fail 'FG did not restore saved RAW TTY mode'
wait_new '# ' "$start" || fail 'shell did not recover after second helper stop'

start=`log_size`
send_line JOBS
wait_new '%1 STOPPED /SYSTEM/EXEC/DSHFGT' "$start" || \
        fail 'helper was not retained after second stop'
wait_new '# ' "$start" || fail 'second JOBS did not return to shell'

# Second FG must use the refreshed COOKED mode.  The helper verifies it and
# exits.  DSH then must reclaim the TTY and restore its RAW editor mode.
start=`log_size`
send_line FG
wait_new 'FGCOOKEDOK' "$start" || fail 'FG did not restore refreshed COOKED mode'
wait_new '# ' "$start" || fail 'shell did not recover after helper exit'
start=`log_size`
send_line 'ECHO DSHFGOK'
wait_new 'DSHFGOK' "$start" || fail 'shell unusable after foreground termination'
wait_new '# ' "$start" || fail 'final DSH prompt missing'

# Repeat the stop/FG cycle with a two-stage pipeline.  The passive HOLD stage
# remains alive while the final helper sends TSTP to the whole pgrp and writes
# its verification output directly to the terminal.
start=`log_size`
send_line '/SYSTEM/EXEC/DSHFGT HOLD ! /SYSTEM/EXEC/DSHFGT KILL'
wait_new '# ' "$start" || fail 'shell did not recover after pipeline stop'
start=`log_size`
send_line JOBS
wait_new '%1 STOPPED /SYSTEM/EXEC/DSHFGT ! /SYSTEM/EXEC/D' "$start" || \
        fail 'stopped foreground pipeline missing from JOBS'
wait_new '# ' "$start" || fail 'pipeline JOBS did not return to shell'
start=`log_size`
send_line FG
wait_new 'FGRAWOK' "$start" || fail 'pipeline FG did not restore RAW mode'
wait_new '# ' "$start" || fail 'shell did not recover after pipeline re-stop'
start=`log_size`
send_line FG
wait_new 'FGCOOKEDOK' "$start" || fail 'pipeline FG did not restore COOKED mode'
# The controller terminates its own pgrp after the final verification so the
# passive HOLD member cannot leak beyond the pipeline test.
wait_new '# ' "$start" || fail 'shell did not recover after pipeline pgrp termination'

# Build two stopped background readers.  Default FG must select the most recent
# job (%2 HEAD), not the older CAT.  HEAD exits after one input record; CAT
# would remain foreground waiting for EOF, so the returned shell prompt proves
# both recency selection and foreground handoff.
start=`log_size`
send_line 'CAT &'
wait_new '%1' "$start" || fail 'first multi-job slot was not allocated'
start=`log_size`
send_line 'HEAD 1 &'
wait_new '%2' "$start" || fail 'second multi-job slot was not allocated'
sleep 0.4
start=`log_size`
send_line JOBS
wait_new '%1 STOPPED CAT' "$start" || fail 'older stopped CAT missing'
wait_new '%2 STOPPED HEAD' "$start" || fail 'newer stopped HEAD missing'
wait_new '# ' "$start" || fail 'multi-job JOBS did not return to shell'
start=`log_size`
send_line FG
sleep 0.4
send_line LATESTFG
wait_new 'LATESTFG' "$start" || fail 'default FG did not run recent reader'
wait_new '# ' "$start" || fail 'default FG selected CAT instead of recent HEAD'
start=`log_size`
send_line JOBS
wait_new '%1 STOPPED CAT' "$start" || fail 'older CAT was not preserved'
wait_new '# ' "$start" || fail 'post-default-FG JOBS did not return to shell'

printf '%s\n' "$tag: PASS (Ctrl-C edit cancel, single/pipeline FG TTY restore, shell recovery, multi-job default FG recency)"
