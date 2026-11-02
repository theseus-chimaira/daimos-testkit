#!/bin/sh
set -eu

# covers-command MOUNT.TSFS

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
. "$self/../lib/daimos-tsfs-tape-root-v117.sh"
tag=daimos-tsfs-mount-v1
work="$TMPDIR/$tag-$$"
build=${DAIMOS_TSFS_PREBUILT_BUILD:-$work/build}
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
tsfs_wait_ticks=${DAIMOS_TSFS_WAIT_TICKS:-2400}
tsfs_simh=${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6}

cleanup()
{
        for pid in "$dcs_pid" "$simh_pid"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        exec 3>&- 4>&- 2>/dev/null || true
        if [ "${DAIMOS_TSFS_KEEP_WORK:-0}" != 1 ]; then
                rm -rf "$work"
        fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/media"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$self/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "$self/../../tools/tcp-run-v1.c"

"$make_cmd" -C "$PDP10_TOOLS_REPO" build BUILD_ROOT="$build" >/dev/null
"$build/tools/host/mktsfs" -n 3 -i 1:2345 -g 7 -o "$work/media/member" >/dev/null

# A tape-root image contains the resident TSFS provider.  Disk-root images
# intentionally omit it to conserve memory, so they cannot test MOUNT.TSFS.
if [ -z "${DAIMOS_TSFS_PREBUILT_BUILD:-}" ]; then
        PATH="$PDP10_PREFIX/bin:$PATH" \
                "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
                BUILD="$build" USERLAND_BUILD_ROOT="$build" \
                ROOT=tape BOOT=ptr \
                PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
                DAS_REPO="$DAS_REPO" HOST_TOOLS="$build/tools/host" \
                SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
fi
daimos_tsfs_prepare_secondary_v117 "$build" "$work" \
        "$build/tools/host/mktsfs"

"$self/../lib/daimos-simh-headless.sh" "$build/boot.tsfs-secondary.ini" \
        "$build/boot.headless.ini" "$dcs_port" "$ge_port"

mkfifo "$cty_in" "$dcs_in"
exec 3<>"$cty_in"
exec 4<>"$dcs_in"
(
        cd "$build"
        TERM=dumb exec "$pty" -r "$tsfs_simh" boot.headless.ini \
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
        ticks=${4:-$tsfs_wait_ticks}
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
send_slow 'MOUNT.TSFS /DEV/DTC4 /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" "$tsfs_wait_ticks" || \
        fail_logs 'MOUNT.TSFS did not return to DSH'

start=`log_size "$dcs_out"`
send_slow 'STAT /MOUNT/DT0'
wait_new "$dcs_out" '/MOUNT/DT0 TYPE 1 WORDS 0 MODE 0555' "$start" || \
        fail_logs 'mounted TSFS root has wrong type/mode'

start=`log_size "$dcs_out"`
send_slow 'LS /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'empty TSFS root cannot be listed'

start=`log_size "$dcs_out"`
send_slow 'ECHO TSFSMOUNTOK'
wait_new "$dcs_out" TSFSMOUNTOK "$start" || fail_logs 'DSH did not resume after helper exit'

printf '%s\n' "$tag: PASS (userspace scan, descriptor handoff, readonly TSFS root mount and helper reap)"
