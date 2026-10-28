#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-dtfs-tape-root-mount-v578
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
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
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

"$make_cmd" -C "$PDP10_TOOLS_REPO" build BUILD_ROOT="$build" >/dev/null
: >"$work/empty"
cat > "$work/manifest" <<EOF
D /SYSTEM
D /SYSTEM/EXEC
F /SYSTEM/EXEC/HELLO $work/empty
F /README $work/empty
D /DOC
F /DOC/INDEX $work/empty
EOF
"$build/tools/host/mktsfs" -n 3 -i 1:2345 -g 7 \
        -m "$work/manifest" -o "$work/media/member" >/dev/null

# Boot from tape so the resident TSFS provider is actually installed.
if [ -z "${DAIMOS_TSFS_PREBUILT_BUILD:-}" ]; then
        PATH="$PDP10_PREFIX/bin:$PATH" \
                "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
                BUILD="$build" USERLAND_BUILD_ROOT="$build" \
                ROOT=tape BOOT=ptr \
                PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
                HOST_TOOLS="$build/tools/host" \
                SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
fi
# Add test-only directory records to the actual TSFS root media.  No
# secondary-mount command or retired MOUNT.TSFS binary is involved.
cp "$build/tsfs-root.manifest" "$work/root-v577.manifest"
cat >> "$work/root-v577.manifest" <<EOF
D /DOC 0555 0 0
F /README $work/empty 0444 0 0
F /DOC/INDEX $work/empty 0444 0 0
F /SYSTEM/EXEC/HELLO $work/empty 0555 0 0
D /MOUNT/DT0 0755 0 0
EOF
"$build/tools/host/mktsfs" -n 3 -i 1:1 -g 1 \
    -m "$work/root-v577.manifest" -o "$work/media/root-v577" >/dev/null
cp "$work/media/root-v5770.dta" "$build/media/dtc0.tap"
cp "$work/media/root-v5771.dta" "$build/media/dtc1.tap"
cp "$work/media/root-v5772.dta" "$build/media/dtc2.tap"
"$self/../lib/daimos-simh-headless.sh" "$build/boot.ini" \
        "$build/boot.headless.ini" "$dcs_port" "$ge_port"

mkfifo "$cty_in" "$dcs_in"
exec 3<>"$cty_in"
exec 4<>"$dcs_in"
(
        cd "$build"
        TERM=dumb exec "$pty" -r "$tsfs_simh" \
                boot.headless.ini \
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
# With a DTC-selected root, DTFS MRES is installed.  Exercise a real
# native-format secondary DECtape rather than obsolete MOUNT.TSFS.
send_slow 'MKFS.DTFS -O NATIVE /DEV/DTC3'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'secondary DTFS format did not return'
start=`log_size "$dcs_out"`
send_slow 'FSCK.DTFS -O NATIVE /DEV/DTC3'
wait_new "$dcs_out" 'FSCK.DTFS NATIVE OK' "$start" || \
    fail_logs 'secondary native DTFS failed validation'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'secondary DTFS check did not return'
start=`log_size "$dcs_out"`
send_slow 'MOUNT.DTFS /DEV/DTC3 /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'DTFS mount did not return'
start=`log_size "$dcs_out"`
send_slow 'STAT /MOUNT/DT0'
wait_new "$dcs_out" '/MOUNT/DT0 TYPE 1' "$start" || \
    fail_logs 'secondary native DTFS mount root stat failed'
start=`log_size "$dcs_out"`
send_slow 'UNMOUNT /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'secondary native DTFS unmount did not return'
start=`log_size "$dcs_out"`
send_slow 'ECHO DTFSMOUNTOK'
wait_new "$dcs_out" DTFSMOUNTOK "$start" || fail_logs 'DSH did not resume after helper exit'

printf '%s\n' "$tag: PASS (tape-root installed DTFS MRES, secondary native mount/stat/unmount)"
