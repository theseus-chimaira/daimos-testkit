#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-tsfs-dir-v2
work="$TMPDIR/$tag-$$"
build="$work/build"
pty="$work/pty-run"
tcp="$work/tcp-run"
cty_in="$work/cty.in"
dcs_in="$work/dcs.in"
cty_out="$work/cty.out"
dcs_out="$work/dcs.out"
simh_pid=
dcs_pid=
dcs_port=$((20000 + ($$ % 10000)))
ge_port=$((40000 + ($$ % 10000)))

cleanup()
{
        for pid in "$dcs_pid" "$simh_pid"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        exec 3>&- 4>&- 2>/dev/null || true
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/media"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

"$make_cmd" -C "$PDP10_TOOLS_REPO" mktsfs >/dev/null
: >"$work/empty"
cat > "$work/manifest" <<EOF
D /SYSTEM
D /SYSTEM/EXEC
F /SYSTEM/EXEC/HELLO $work/empty
F /README $work/empty
D /DOC
F /DOC/INDEX $work/empty
EOF
"$PDP10_TOOLS_REPO/mktsfs" -n 3 -i 1:2345 -g 7 \
        -m "$work/manifest" -o "$work/media/member" >/dev/null

# Build a fresh D6FS image for this single boot.  D6FS marks a mounted root
# DIRTY, so reusing a previous test image would turn a later boot failure into
# a false TSFS regression.
PATH="$PDP10_PREFIX/bin:$PATH" \
        "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build" USERLAND_BUILD_ROOT="$build" \
        PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
cp "$work/media/member0.dta" "$build/media/dtc0.tap"
cp "$work/media/member1.dta" "$build/media/dtc1.tap"
cp "$work/media/member2.dta" "$build/media/dtc2.tap"

mkfifo "$cty_in" "$dcs_in"
exec 3<>"$cty_in"
exec 4<>"$dcs_in"
(
        cd "$build"
        TERM=dumb exec "$pty" -r "$PDP10_PREFIX/bin/pdp6" boot.ini \
                <"$cty_in" >"$cty_out" 2>&1
) &
simh_pid=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$dcs_in" >"$dcs_out" 2>&1 &
dcs_pid=$!

log_size()
{
        if [ -f "$1" ]; then wc -c <"$1" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        file=$1
        pattern=$2
        start=$3
        ticks=${4:-700}
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
        echo '--- CTY ---' >&2
        cat "$cty_out" >&2 || true
        echo '--- DCS0 ---' >&2
        cat "$dcs_out" >&2 || true
        echo "$tag: $1" >&2
        exit 1
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

wait_new "$dcs_out" 'Connected to the PDP6 simulator DCS device' 0 || \
        fail_logs 'DCS0 transport did not connect'
start=`log_size "$dcs_out"`
send_slow ''
wait_new "$dcs_out" 'LOGIN: ' "$start" || fail_logs 'DCS0 LOGIN did not reprompt'
start=`log_size "$dcs_out"`
send_slow ROOT
wait_new "$dcs_out" 'DSH V1' "$start" || fail_logs 'ROOT login did not enter DSH'

start=`log_size "$dcs_out"`
send_slow 'MOUNT.TSFS /DEV/DTC0 /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" 900 || fail_logs 'MOUNT.TSFS did not return to DSH'

start=`log_size "$dcs_out"`
send_slow 'STAT /MOUNT/DT0'
wait_new "$dcs_out" '/MOUNT/DT0 TYPE 1 WORDS 0 MODE 0555' "$start" || \
        fail_logs 'mounted TSFS root has wrong type/mode'

start=`log_size "$dcs_out"`
send_slow 'LS /MOUNT/DT0'
wait_new "$dcs_out" 'SYSTEM' "$start" || fail_logs 'root listing misses SYSTEM'
wait_new "$dcs_out" 'README' "$start" || fail_logs 'root listing misses README'
wait_new "$dcs_out" 'DOC' "$start" || fail_logs 'root listing misses DOC'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'non-empty TSFS root cannot be listed'

start=`log_size "$dcs_out"`
send_slow 'LS /MOUNT/DT0/SYSTEM/EXEC'
wait_new "$dcs_out" 'HELLO' "$start" || fail_logs 'nested lookup/list misses HELLO'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'nested TSFS directory cannot be listed'

start=`log_size "$dcs_out"`
send_slow 'STAT /MOUNT/DT0/README'
wait_new "$dcs_out" '/MOUNT/DT0/README TYPE 2 WORDS 0 MODE 0444' "$start" || \
        fail_logs 'TSFS regular-file stat is wrong'

start=`log_size "$dcs_out"`
send_slow 'STAT /MOUNT/DT0/SYSTEM'
wait_new "$dcs_out" '/MOUNT/DT0/SYSTEM TYPE 1 WORDS 0 MODE 0555' "$start" || \
        fail_logs 'TSFS directory stat is wrong'

start=`log_size "$dcs_out"`
send_slow 'ECHO TSFSDIROK'
wait_new "$dcs_out" TSFSDIROK "$start" || fail_logs 'DSH did not resume after helper exit'

printf '%s\n' "$tag: PASS (metadata-backed lookup, readdir and stat)"
