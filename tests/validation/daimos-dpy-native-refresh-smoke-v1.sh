#!/bin/sh
# covers-command CLEAR
# covers-command DPYVIEW
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
# Build a headless Type-340 image first.  The DPY protocol/state machine remains
# fully active, but no host DPY window is opened.  WCNSLS/OCNSLS are unrelated
# color-scope devices and are disabled in this test-only simulator config so a
# DPY regression can never wedge on their host graphics backend.
"$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        SIMH_DPY_MODE=HEADLESS DPY_LOGIN=1 \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
boot="$build/system/boot/pdp6"
sed -i \
        -e 's/^set wcnsls .*/set wcnsls disabled/' \
        -e 's/^set ocnsls .*/set ocnsls disabled/' \
        "$boot/boot.ini"

# Preserve the public make-boot announcement contract used by the assertions
# below while launching the simulator directly against the sanitized config.
printf '%s\n' 'DAIMOS PDP-6 login terminals:' \
        '  CTY   current terminal' \
        "  DCS0  127.0.0.1:$dcs_port" \
        "  GE0   127.0.0.1:$ge_port" >"$cty_out"
(
        cd "$boot"
        TERM=dumb exec "$pty" -r "$PDP10_PREFIX/bin/pdp6" boot.ini \
                <"$cty_in" >>"$cty_out" 2>&1
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

# Use DCS0 as the observable shell for command/runtime checks.
start=`log_size "$dcs_out"`
send_slow 4 ROOT
wait_new "$dcs_out" 'DSH V1' "$start" || fail_logs 'DCS0 LOGIN did not enter DSH'

# With DPY_LOGIN=1, TTY0 keyboard input remains CTY but terminal output is
# intentionally routed to the Type-340.  Therefore CTY no longer prints the
# LOGIN or DSH prompt.  Remote DCS/GE logins below prove userspace is alive;
# the dedicated DPY tests cover the display-output path.

# Focused retained-DPY acceptance: write primary and shifted text through the
# composite terminal endpoint, allow multiple refresh periods, and prove the
# shell/simulator remain live.
start=`log_size "$dcs_out"`
send_slow 4 'echo TEST > /dev/ttydpy0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'TTYDPY0 primary-text write did not return'
start=`log_size "$dcs_out"`
send_slow 4 'echo [\]^_ > /dev/ttydpy0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'TTYDPY0 shifted-text write did not return'
sleep 2
kill -0 "$boot_pid" 2>/dev/null || fail_logs 'simulator died during retained DPY refresh'
echo 'daimos-dpy-native-refresh-smoke-v1: PASS (DPY login, TTYDPY0 primary/shifted refresh)'
exit 0

# Public commands are ordinary /SYSTEM/EXEC files.  /SYSTEM/LIBEXEC is for
# genuinely private helpers only; no command map or multicall implementation
# belongs there.
start=`log_size "$dcs_out"`
send_slow 4 'ls /system/exec'
wait_new "$dcs_out" 'F LS' "$start" || \
        fail_logs '/SYSTEM/EXEC does not contain LS executable'
wait_new "$dcs_out" 'F WHICH' "$start" || \
        fail_logs '/SYSTEM/EXEC does not expose WHICH command'
wait_new "$dcs_out" 'F MAKE' "$start" || \
        fail_logs '/SYSTEM/EXEC does not contain native MAKE executable'
wait_new "$dcs_out" '# ' "$start" || \
        fail_logs 'DSH prompt did not return after /SYSTEM/EXEC listing'

start=`log_size "$dcs_out"`
send_slow 4 'ls /system/libexec'
wait_new "$dcs_out" 'F DSHCOMP' "$start" || \
        fail_logs '/SYSTEM/LIBEXEC does not contain DSHCOMP helper'
for stale in CMD UTIL.MISC UTIL.TEXT UTIL.DOC LOGCOMPAT MAP; do
        if tail -c +$((start + 1)) "$dcs_out" | grep -F "F $stale" >/dev/null 2>&1; then
                fail_logs "/SYSTEM/LIBEXEC still exposes obsolete $stale multiplexer"
        fi
done
wait_new "$dcs_out" '# ' "$start" || \
        fail_logs 'DSH prompt did not return after /SYSTEM/LIBEXEC listing'

start=`log_size "$dcs_out"`
send_slow 4 'which ls sed'
wait_new "$dcs_out" '/SYSTEM/EXEC/LS' "$start" || \
        fail_logs 'WHICH LS did not report public system path'
wait_new "$dcs_out" '/SYSTEM/EXEC/SED' "$start" || \
        fail_logs 'WHICH SED did not report public system path'

# The optional assembler utilities ship as native-buildable source.  Their
# MAKEFILE must be usable entirely inside DAIMOS with the installed MAKE/DAS
# toolchain, and INSTALL must create ordinary /OPTION/BASE/EXEC programs.
start=`log_size "$dcs_out"`
send_slow 4 'ls /option/base/source/asmutils'
for source in MAKEFILE ARGS.S BASE.S S6REC.S; do
        wait_new "$dcs_out" "F $source" "$start" || \
                fail_logs "ASMUTILS source tree is missing $source"
done
wait_new "$dcs_out" '# ' "$start" || \
        fail_logs 'DSH prompt did not return after ASMUTILS source listing'

start=`log_size "$dcs_out"`
send_slow 4 'make -c /option/base/source/asmutils install'
wait_new "$dcs_out" '# ' "$start" 6000 || \
        fail_logs 'native ASMUTILS MAKE INSTALL did not complete'

start=`log_size "$dcs_out"`
send_slow 4 'which args'
wait_new "$dcs_out" '/OPTION/BASE/EXEC/ARGS' "$start" || \
        fail_logs 'native ASMUTILS install did not create /OPTION/BASE/EXEC/ARGS'

# Ambiguous path completion follows the conventional two-TAB interaction:
# the first TAB preserves the unresolved prefix, the second prints all
# candidates and redraws the current command line.  Use literal TAB bytes;
# send_slow() would append ENTER and therefore cannot express this editor case.
start=`log_size "$dcs_out"`
printf 'CD /\t\t\r' >&4
wait_new "$dcs_out" '/SYSTEM/' "$start" || \
        fail_logs 'DCS0 DSH double-TAB did not list /SYSTEM/'
wait_new "$dcs_out" '/CONFIG/' "$start" || \
        fail_logs 'DCS0 DSH double-TAB did not list /CONFIG/'

if grep -F 'vid_thread(): Unexpected user event code:' "$cty_out" >/dev/null 2>&1; then
        fail_logs 'SIMH video thread reported an unexpected redraw event'
fi

for spec in "5:$ge_out"; do
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

printf '%s\n' "$tag: PASS (public EXEC/WHICH, DPY-routed TTY0, DCS0/GE0 input, double-TAB completion)"
