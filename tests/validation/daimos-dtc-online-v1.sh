#!/bin/sh
set -eu

# covers-command MKFS.DTFS
# covers-command FSCK.DTFS
# covers-command MOUNT
# covers-command MOUNT.DTFS

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-dtc-online-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
media="$work/dtc0.tap"
pristine="$work/disk-pristine"
tcp="$work/tcp-run"
sim_pid=
tcp_pid=
dcs_fd_open=0
simh_out=
dcs_out=
dcs_in=

cleanup()
{
        for pid in "$tcp_pid" "$sim_pid"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        if [ "$dcs_fd_open" -ne 0 ]; then
                exec 3>&- 2>/dev/null || true
        fi
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$work"
touch "$media"
"$host_cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

# Build once to create the system disk and userland.  DTC0 is deliberately
# wired to media outside the build tree so the formatted tape survives the
# pristine-root restore between the two target boots.
PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    DTC0_IMAGE="$media" >/dev/null
cp -R "$boot/disk" "$pristine"

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
        ticks=${4:-400}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                        tr -d '\r' | grep -F "$pattern" >/dev/null 2>&1; then
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

fail_run()
{
        msg=$1
        echo "--- CTY/SIMH ---" >&2
        tr -d '\r' < "$simh_out" >&2 || true
        echo "--- DCS0 ---" >&2
        tr -d '\r' < "$dcs_out" >&2 || true
        echo "$tag: $msg" >&2
        exit 1
}

start_run()
{
        name=$1
        dcs_port=$2
        ge_port=$3
        simh_out="$work/$name.simh"
        dcs_out="$work/$name.dcs"
        dcs_in="$work/$name.in"

        PATH="$PDP10_PREFIX/bin:$PATH" \
            "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
            DTC0_IMAGE="$media" \
            SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

        rm -f "$dcs_in"
        mkfifo "$dcs_in"
        exec 3<>"$dcs_in"
        dcs_fd_open=1
        (
                cd "$boot"
                TERM=dumb exec "$PDP10_PREFIX/bin/pdp6" boot.ini
        ) >"$simh_out" 2>&1 &
        sim_pid=$!
        "$tcp" 127.0.0.1 "$dcs_port" <"$dcs_in" >"$dcs_out" 2>&1 &
        tcp_pid=$!

        wait_new "$dcs_out" 'Connected to the PDP6 simulator DCS device' 0 300 || \
                fail_run 'DCS0 transport did not connect'
        # Carrier can arrive after INIT emitted its first prompt; request a
        # fresh prompt only after the TCP transport is confirmed live.
        start=`log_size "$dcs_out"`
        send_slow ''
        wait_new "$dcs_out" 'LOGIN: ' "$start" 600 || \
                fail_run 'LOGIN prompt missing'
        start=`log_size "$dcs_out"`
        send_slow ROOT
        wait_new "$dcs_out" 'DSH V1' "$start" 600 || \
                fail_run 'ROOT login did not enter DSH'
}

stop_run()
{
        send_slow HALT
        i=0
        while kill -0 "$sim_pid" 2>/dev/null && [ "$i" -lt 200 ]; do
                sleep 0.1
                i=$((i + 1))
        done
        if kill -0 "$sim_pid" 2>/dev/null; then
                fail_run 'HALT did not stop simulator'
        fi
        wait "$sim_pid" 2>/dev/null || true
        sim_pid=
        wait "$tcp_pid" 2>/dev/null || true
        tcp_pid=
        exec 3>&-
        dcs_fd_open=0
}

# First boot: create a native DTFS image on the real emulated Type-551 path
# and verify it before shutting down the target.
port1=$((23000 + ($$ % 4000)))
ge1=$((41000 + ($$ % 4000)))
start_run run1 "$port1" "$ge1"
start=`log_size "$dcs_out"`
send_slow 'MKFS.DTFS -O NATIVE /DEV/DTC0'
wait_new "$dcs_out" '# ' "$start" 600 || fail_run 'MKFS.DTFS did not return'
start=`log_size "$dcs_out"`
send_slow 'FSCK.DTFS -O NATIVE /DEV/DTC0'
wait_new "$dcs_out" 'FSCK.DTFS NATIVE OK' "$start" 600 || \
        fail_run 'native filesystem check failed'
wait_new "$dcs_out" '# ' "$start" 600 || fail_run 'FSCK.DTFS prompt missing'
stop_run

run1_dcs="$work/run1.dcs"
run1_simh="$work/run1.simh"
grep -Eq '^DTC[[:space:]]+OK' "$run1_simh" || {
        cat "$run1_simh" >&2
        echo "$tag: DTC did not probe" >&2
        exit 1
}
if tr -d '\r' < "$run1_dcs" | grep -q '^MKFS.DTFS:'; then
        cat "$run1_dcs" >&2
        echo "$tag: format reported an error" >&2
        exit 1
fi
[ -s "$media" ] || {
        echo "$tag: format produced no DECtape media" >&2
        exit 1
}

# Second boot starts with a pristine DSK root so persisted DTFS data must come
# from the DECtape file rather than kernel/controller cache state.
rm -rf "$boot/disk"
cp -R "$pristine" "$boot/disk"
port2=$((27000 + ($$ % 4000)))
ge2=$((45000 + ($$ % 4000)))
start_run run2 "$port2" "$ge2"
start=`log_size "$dcs_out"`
send_slow 'MOUNT /DEV/DTC0 /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" 600 || fail_run 'MOUNT did not return'
start=`log_size "$dcs_out"`
send_slow 'UNMOUNT /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" 600 || fail_run 'UNMOUNT did not return'
start=`log_size "$dcs_out"`
send_slow 'MOUNT.DTFS /DEV/DTC0 /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" 600 || fail_run 'MOUNT.DTFS did not return'
stop_run

run2_dcs="$work/run2.dcs"
run2_simh="$work/run2.simh"
grep -Eq '^DTC[[:space:]]+OK' "$run2_simh" || {
        cat "$run2_simh" >&2
        echo "$tag: DTC did not probe on second boot" >&2
        exit 1
}
if tr -d '\r' < "$run2_dcs" | grep -Eq '^MOUNT(\.DTFS)?:'; then
        cat "$run2_dcs" >&2
        echo "$tag: persisted-media mount reported an error" >&2
        exit 1
fi
clean2="$work/run2.clean"
tr -d '\r' < "$run2_dcs" > "$clean2"
grep -q '^# MOUNT /DEV/DTC0 /MOUNT/DT0' "$clean2" || {
        cat "$run2_dcs" >&2
        echo "$tag: mount command was not executed" >&2
        exit 1
}
grep -q '^# MOUNT.DTFS /DEV/DTC0 /MOUNT/DT0' "$clean2" || {
        cat "$run2_dcs" >&2
        echo "$tag: compatibility mount command was not executed" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (Type-551 persisted format/write and rebooted mount/read through DCS login)"
