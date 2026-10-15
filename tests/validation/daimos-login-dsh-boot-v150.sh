#!/bin/sh
# Fresh PDP-6 D6FS boot through LOGIN and ROOT shell at 64K, 128K or 256K.
# Keep this separate from the earlier PC-zero survival tests: only a prompt
# and a working native shell establish interactive boot acceptance.
set -eu
: "${DAIMOS_REPO:?Set DAIMOS_REPO}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"
: "${TMPDIR:?Set TMPDIR}"
size=${1:-64}
profile=${BOOT_PROFILE:-lowmem}
case "$profile" in
    full|lowmem) ;;
    *) echo 'BOOT_PROFILE must be full or lowmem' >&2; exit 2 ;;
esac
case "$size" in
    64) core=0200000 ;;
    128) core=0400000 ;;
    256) core=01000000 ;;
    *) echo 'usage: daimos-login-dsh-boot-v150.sh [64|128|256]' >&2; exit 2 ;;
esac

work="$TMPDIR/daimos-login-dsh-v150-${profile}-${size}k-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
port=$((24000 + ($$ % 7000)))
ge_port=$((port + 10000))
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
sim_pid=
tcp_pid=
mkdir -p "$work"

cleanup()
{
    for pid in "$tcp_pid" "$sim_pid"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || :
            wait "$pid" 2>/dev/null || :
        fi
    done
    exec 3>&- 2>/dev/null || :
}
trap cleanup EXIT HUP INT TERM

cc -std=c99 -O2 -Wall -Wextra -Werror -o "$work/tcp-run" \
    "$(dirname "$0")/../../tools/tcp-run-v1.c"

make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BOOT_PROFILE="$profile" ROOT=disk BOOT=dsk COMPILER=gcc \
    BOOT_CORE_WORDS="$core" SIMH_CPU_KWORDS="$size" \
    SIMH_DCS0_PORT="$port" SIMH_GE0_PORT="$ge_port" \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$build" \
    > "$work/build.log" 2>&1 || {
        tail -35 "$work/build.log" >&2
        exit 1
    }

sh "$(dirname "$0")/check-d6lz-fixed-placement-v142.sh" "$boot/kcore.map"
mkfifo "$work/dcs.in"
exec 3<>"$work/dcs.in"
(
    cd "$boot"
    SDL_VIDEODRIVER=dummy TERM=dumb exec "$simh" boot.ini
) > "$work/cty.log" 2>&1 &
sim_pid=$!
"$work/tcp-run" 127.0.0.1 "$port" < "$work/dcs.in" > "$work/dcs.log" 2>&1 &
tcp_pid=$!

wait_for()
{
    pattern=$1
    i=0
    while [ "$i" -lt 750 ]; do
        if tr -d '\r' < "$work/dcs.log" 2>/dev/null |
            grep -F "$pattern" >/dev/null 2>&1; then
            return 0
        fi
        kill -0 "$sim_pid" 2>/dev/null || return 1
        sleep 0.1
        i=$((i + 1))
    done
    return 1
}

fail()
{
    echo "FAIL: $1 (logs retained in $work)" >&2
    tail -35 "$work/cty.log" >&2 || :
    tail -35 "$work/dcs.log" >&2 || :
    exit 1
}

wait_for 'Connected to the PDP6 simulator DCS device' || fail 'DCS0 not connected'
printf '\r' >&3
wait_for 'LOGIN: ' || fail 'LOGIN prompt not received'
printf 'ROOT\r' >&3
wait_for 'DSH V1' || fail 'ROOT did not enter DSH'
if grep -E 'HALT instruction|\?RT|MEMFS NOT MOUNTED|EXEC FAILED' \
    "$work/cty.log" "$work/dcs.log" >/dev/null 2>&1; then
    fail 'boot produced a fatal error'
fi
echo "PASS: ${profile} ${size}K boot reached DCS0 LOGIN, ROOT, DSH V1 (logs: $work)"
