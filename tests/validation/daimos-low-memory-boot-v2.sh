#!/bin/sh
set -eu

# covers-command DATE

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
tag=daimos-low-memory-boot-v2
work="$TMPDIR/$tag-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
run="$work/run"
tcp="$work/tcp-run"
in="$work/dcs.in"
out="$work/dcs.out"
cty="$work/cty.out"
dcs_port=$((23000 + ($$ % 8000)))
ge_port=$((41000 + ($$ % 8000)))
sim_pid=
tcp_pid=

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
mkdir -p "$run"

"$host_cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BOOT_PROFILE=lowmem BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
    SIMH_PCLK_MODE=REALTIME >/dev/null

image_end=$(awk '$1 == "__kinit_image_end" { print $2; exit }' "$boot/kinit.map")
case "$image_end" in
''|*[!0-7]*)
        echo "$tag: missing KINIT image end" >&2
        exit 1
        ;;
esac
if [ "$((0$image_end))" -gt "$((0076000))" ]; then
        echo "$tag: KINIT image exceeds 32K stack-safe ceiling: $image_end" >&2
        exit 1
fi
if grep -Eq '^(badmap_minit|badmap_mres_package|blockset_boot_badmap_count)[[:space:]]' \
    "$boot/kinit.map"; then
        echo "$tag: optional BADMAP returned to LOWMEM bootstrap" >&2
        exit 1
fi
if [ "$(sed -n '3p' "$boot/kinit.lowmem.words")" != 000000000000 ]; then
        echo "$tag: LOWMEM boot stream is not direct/raw mode" >&2
        exit 1
fi
grep -Eq '^set cpu 32k$' "$boot/boot.ini" || {
        echo "$tag: simulator is not configured for 32K" >&2
        exit 1
}
grep -Eq '^set pclk REALTIME$' "$boot/boot.ini" || {
        echo "$tag: REALTIME PCLK configuration missing" >&2
        exit 1
}

mkfifo "$in"
exec 3<>"$in"
(
        cd "$boot"
        TERM=dumb exec "$simh" boot.ini
) >"$cty" 2>&1 &
sim_pid=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$in" >"$out" 2>&1 &
tcp_pid=$!

wait_for()
{
        file=$1
        pattern=$2
        ticks=${3:-900}
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

fail_logs()
{
        echo "--- CTY ---" >&2
        tr -d '\r' <"$cty" >&2 || true
        echo "--- DCS0 ---" >&2
        tr -d '\r' <"$out" >&2 || true
        echo "$tag: $1" >&2
        exit 1
}

wait_for "$out" 'Connected to the PDP6 simulator DCS device' 300 || \
        fail_logs 'DCS0 transport did not connect'
# Carrier may arrive after INIT emitted its first prompt.  Ask for a fresh one.
printf '\r' >&3
wait_for "$out" 'LOGIN: ' 600 || fail_logs 'DCS0 LOGIN missing'
printf 'ROOT\r' >&3
wait_for "$out" 'DSH V1' 600 || fail_logs 'ROOT login did not enter DSH'

before=$(date -u +%Y-%m-%d)
printf 'MEMSTAT\r' >&3
wait_for "$out" 'RESIDENT ' 200 || fail_logs 'MEMSTAT did not return'
printf 'DATE\r' >&3
wait_for "$out" ' UTC' 200 || fail_logs 'DATE did not return'
after=$(date -u +%Y-%m-%d)
clean="$work/dcs.clean"
tr -d '\r' <"$out" >"$clean"

grep -Eq '^PROCESS-WORDS [1-9][0-9]*$' "$clean" || \
        fail_logs 'resident process accounting missing'
grep -Eq '^MEMFS-CAPACITY 0$' "$clean" || \
        fail_logs 'MEMFS must remain unmounted in the 32K low-memory profile'
if ! grep -F "$before " "$clean" >/dev/null 2>&1 && \
   ! grep -F "$after " "$clean" >/dev/null 2>&1; then
        fail_logs 'DATE does not match host UTC calendar date'
fi
if grep -q 'MNTERR' "$clean"; then
        fail_logs 'boot reported MNTERR'
fi
if tr -d '\r' <"$cty" | grep -Eq 'INIT: (RUN|RESPAWN) FAILED'; then
        fail_logs '32K profile could not keep its configured login service alive'
fi

printf 'EXIT\r' >&3
printf '%s\n' "$tag: PASS (32K LOWMEM raw boot, DCS ROOT -> DSH, MEMSTAT, REALTIME PCLK DATE)"
