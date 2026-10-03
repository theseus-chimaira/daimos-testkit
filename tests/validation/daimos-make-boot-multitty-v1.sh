#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-make-boot-multitty-v1
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
boot_pid=
dcs_pid=
ge_pid=
dcs_port=$((21000 + ($$ % 9000)))
ge_port=$((41000 + ($$ % 9000)))

cleanup()
{
        for pid in "$ge_pid" "$dcs_pid" "$boot_pid"; do
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

"$host_cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

mkfifo "$cty_in" "$dcs_in" "$ge_in"
exec 3<>"$cty_in"
exec 4<>"$dcs_in"
exec 5<>"$ge_in"
(
        TERM=dumb exec "$pty" -r "$make_cmd" -C "$DAIMOS_REPO" boot \
                BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
                SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
                <"$cty_in" >"$cty_out" 2>&1
) &
boot_pid=$!
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
        ticks=${4:-900}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                        grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$boot_pid" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

fail_logs()
{
        echo "--- CTY / make boot ---" >&2
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

# This banner belongs to the public top-level make boot contract.  It also
# proves that the requested remote ports reached the top-level boot recipe.
wait_new "$cty_out" 'DAIMOS PDP-6 login terminals:' 0 300 || \
        fail_logs 'make boot did not announce the three-terminal configuration'
wait_new "$cty_out" "DCS0  127.0.0.1:$dcs_port" 0 100 || \
        fail_logs 'make boot did not announce DCS0'
wait_new "$cty_out" "GE0   127.0.0.1:$ge_port" 0 100 || \
        fail_logs 'make boot did not announce GE0'

wait_new "$cty_out" 'LOGIN: ' 0 || fail_logs 'CTY LOGIN missing'
wait_new "$cty_out" 'DPY                                   OK' 0 || \
        fail_logs 'Type 340 DPY did not probe successfully'
wait_new "$dcs_out" 'Connected to the PDP6 simulator DCS device' 0 || \
        fail_logs 'DCS0 transport did not connect'
wait_new "$ge_out" 'Connected to the PDP6 simulator GE device' 0 || \
        fail_logs 'GE0 transport did not connect'

# A remote LOGIN may have printed before carrier arrived.  Force a fresh prompt.
for spec in "4:$dcs_out" "5:$ge_out"; do
        fd=${spec%%:*}
        file=${spec#*:}
        start=`log_size "$file"`
        send_slow "$fd" ''
        wait_new "$file" 'LOGIN: ' "$start" || fail_logs 'remote LOGIN missing'
done

# CTY must remain usable with the GUI display devices enabled.  This catches
# simulator video-event regressions that can leave LOGIN usable but break the
# shell's raw per-character editor path.
start=`log_size "$cty_out"`
send_slow 3 ROOT
wait_new "$cty_out" 'DSH V1' "$start" || fail_logs 'CTY LOGIN did not enter DSH'
start=`log_size "$cty_out"`
send_slow 3 'echo ctyok'
wait_new "$cty_out" 'CTYOK' "$start" || fail_logs 'CTY DSH raw input/echo failed'

# Ambiguous path completion follows the conventional two-TAB interaction:
# the first TAB preserves the unresolved prefix, the second prints all
# candidates and redraws the current command line.  Use literal TAB bytes;
# send_slow() would append ENTER and therefore cannot express this editor case.
start=`log_size "$cty_out"`
printf 'CD /\t\t\r' >&3
wait_new "$cty_out" '/SYSTEM/' "$start" || \
        fail_logs 'CTY DSH double-TAB did not list /SYSTEM/'
wait_new "$cty_out" '/CONFIG/' "$start" || \
        fail_logs 'CTY DSH double-TAB did not list /CONFIG/'

if grep -F 'vid_thread(): Unexpected user event code:' "$cty_out" >/dev/null 2>&1; then
        fail_logs 'SIMH video thread reported an unexpected redraw event'
fi

for spec in "4:$dcs_out" "5:$ge_out"; do
        fd=${spec%%:*}
        file=${spec#*:}
        start=`log_size "$file"`
        send_slow "$fd" ROOT
        wait_new "$file" 'DSH V1' "$start" || fail_logs 'LOGIN did not enter DSH'
        start=`log_size "$file"`
        send_slow "$fd" 'echo remotok'
        wait_new "$file" 'REMOTOK' "$start" || \
                fail_logs 'remote DSH lowercase raw input failed'
done

printf '%s\n' "$tag: PASS (CTY/DCS0/GE0 lowercase raw input plus double-TAB completion)"
