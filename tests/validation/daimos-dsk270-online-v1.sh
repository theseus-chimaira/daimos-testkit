#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-dsk270-online-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
simh_out="$work/simh.out"
dcs_out="$work/dcs.out"
dcs_in="$work/dcs.in"
tcp="$work/tcp-run"
log_out="$work/logstore.out"
fsck_out="$work/d6fsck.out"
sim_pid=
tcp_pid=
dcs_port=$((27000 + ($$ % 5000)))
ge_port=$((42000 + ($$ % 5000)))

cleanup()
{
        for pid in "$tcp_pid" "$sim_pid"; do
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

"$host_cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

boot="$build/system/boot/pdp6"

# Use DCS0 for the interactive path.  CTY injection is deliberately avoided:
# current acceptance has demonstrated that SIMH CTY send can lose characters.
mkfifo "$dcs_in"
exec 3<>"$dcs_in"
(
        cd "$boot"
        TERM=dumb exec "$PDP10_PREFIX/bin/pdp6" boot.ini
) >"$simh_out" 2>&1 &
sim_pid=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$dcs_in" >"$dcs_out" 2>&1 &
tcp_pid=$!

wait_for()
{
        file=$1
        pattern=$2
        ticks=${3:-400}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tr -d '\r' <"$file" 2>/dev/null | grep -F "$pattern" >/dev/null 2>&1; then
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

wait_for "$dcs_out" 'Connected to the PDP6 simulator DCS device' 300 || {
        cat "$simh_out" >&2
        cat "$dcs_out" >&2
        echo "dsk270-online: DCS0 transport did not connect" >&2
        exit 1
}
send_slow ''
wait_for "$dcs_out" 'LOGIN: ' 600 || {
        cat "$dcs_out" >&2
        echo "dsk270-online: LOGIN prompt missing" >&2
        exit 1
}
send_slow ROOT
wait_for "$dcs_out" 'DSH V1' 600 || {
        cat "$dcs_out" >&2
        echo "dsk270-online: ROOT login did not reach DSH" >&2
        exit 1
}
send_slow 'STAT /SYSTEM/INIT'
wait_for "$dcs_out" '/SYSTEM/INIT TYPE 2 WORDS ' 300 || {
        cat "$dcs_out" >&2
        echo "dsk270-online: source STAT failed" >&2
        exit 1
}
send_slow 'CP /SYSTEM/INIT /COPY'
sleep 0.5
send_slow 'STAT /COPY'
wait_for "$dcs_out" '/COPY TYPE 2 WORDS ' 300 || {
        cat "$dcs_out" >&2
        echo "dsk270-online: copy STAT failed" >&2
        exit 1
}

# HALT stops the running validation system after all target-side I/O checks.
# The mounted writable root is expected to remain DIRTY; host-side d6fsck
# below must recognize that state and complete a full recovery scan.
send_slow HALT
i=0
while kill -0 "$sim_pid" 2>/dev/null && [ "$i" -lt 200 ]; do
        sleep 0.1
        i=$((i + 1))
done
if kill -0 "$sim_pid" 2>/dev/null; then
        cat "$simh_out" >&2
        cat "$dcs_out" >&2
        echo "dsk270-online: clean unmount/HALT did not stop simulator" >&2
        exit 1
fi
wait "$sim_pid" 2>/dev/null || true
sim_pid=
wait "$tcp_pid" 2>/dev/null || true
tcp_pid=

grep -Eq '^DSK270[[:space:]]+OK' "$simh_out" || {
        cat "$simh_out" >&2
        echo "dsk270-online: DSK270 did not probe" >&2
        exit 1
}
grep -q 'DSH V1' "$dcs_out" || {
        cat "$dcs_out" >&2
        echo "dsk270-online: disk boot did not reach DSH" >&2
        exit 1
}

tr -d '\r' <"$dcs_out" >"$work/dcs.clean"
src_size=`awk '/^\/SYSTEM\/INIT TYPE 2 WORDS [0-9]+/ { print $5; exit }' "$work/dcs.clean"`
copy_size=`awk '/^\/COPY TYPE 2 WORDS [0-9]+/ { print $5; exit }' "$work/dcs.clean"`
if test -z "$src_size" || test -z "$copy_size" || test "$src_size" != "$copy_size"; then
        cat "$dcs_out" >&2
        echo "dsk270-online: runtime copy size mismatch: source=$src_size copy=$copy_size" >&2
        exit 1
fi
if grep -q '^CP:' "$work/dcs.clean"; then
        cat "$dcs_out" >&2
        echo "dsk270-online: runtime copy reported an error" >&2
        exit 1
fi

if "$PDP10_PREFIX/bin/d6fsck" -n 1 -d "$boot/disk" >"$fsck_out" 2>&1; then
        cat "$fsck_out" >&2
        echo "dsk270-online: live writable root unexpectedly reported CLEAN" >&2
        exit 1
fi
grep -q 'selected superblock DIRTY' "$fsck_out" || {
        cat "$fsck_out" >&2
        echo "dsk270-online: expected recoverable DIRTY root not reported" >&2
        exit 1
}
"$PDP10_PREFIX/bin/d6fsck" -r -n 1 -d "$boot/disk" >"$work/d6fsck.repair" 2>&1 || {
        cat "$work/d6fsck.repair" >&2
        echo "dsk270-online: full recovery scan failed after runtime I/O" >&2
        exit 1
}
"$PDP10_PREFIX/bin/d6fsck" -n 1 -d "$boot/disk" >"$work/d6fsck.final" 2>&1 || {
        cat "$work/d6fsck.final" >&2
        echo "dsk270-online: repaired filesystem did not validate" >&2
        exit 1
}
grep -q ': clean$' "$work/d6fsck.final" || {
        cat "$work/d6fsck.final" >&2
        echo "dsk270-online: repair did not publish CLEAN generation" >&2
        exit 1
}

"$PDP10_PREFIX/bin/logstore" -n 1 -d "$boot/disk" --dump >"$log_out"
if grep -Eq 'valid=1([^0-9]|$)' "$log_out"; then
        cat "$log_out" >&2
        echo "dsk270-online: clean boot created a LOGSTORE record" >&2
        exit 1
fi

printf '%s\n' 'dsk270-online: PASS (boot I/O plus runtime async DSK read/write)'
