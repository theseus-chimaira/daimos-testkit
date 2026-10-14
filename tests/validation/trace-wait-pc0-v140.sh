#!/bin/sh
# Trace an isolated PDP-6 disk-root boot through WAIT and the PC-zero fault.
# Build a new image for each run: the simulator modifies attached D6FS media.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
work="$TMPDIR/wait-pc0-v140-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
mkdir -p "$work"
echo "Trace retained in $work"
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BOOT_PROFILE=lowmem BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
    BOOT=dsk ROOT=disk COMPILER=gcc \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$build" \
    >"$work/build.log" 2>&1 || {
        tail -25 "$work/build.log" >&2
        exit 1
    }
wait_pc=$(awk '$1=="proc_wait_status" {print $2}' "$boot/kcore.map")
slot=$(awk '$1=="proc_current_slot" {print $2}' "$boot/kcore.map")
pi6=$(awk '$1=="pdp10_pi_level6" {print $2}' "$boot/kcore.map")
test -n "$wait_pc" && test -n "$slot" && test -n "$pi6"
sed "/^go 020$/i break $wait_pc" "$boot/boot.ini" |
    sed "/^exit$/i examine $slot\nexamine $pi6\nexamine 17\nnobreak $wait_pc\nbreak 0\ngo\nexamine $slot\nexamine $pi6\nexamine 17" > "$work/trace.ini"
timeout 30 "${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}" "$work/trace.ini" \
    > "$work/trace.log" 2>&1 || :
tr -d '\r' < "$work/trace.log" > "$work/trace.clean"
grep -E 'INIT V1|MEMFS|Breakpoint|HALT|LOGIN:' "$work/trace.clean" || :
grep -F "Breakpoint, PC: $wait_pc" "$work/trace.clean" >/dev/null || exit 1
grep -F 'Breakpoint, PC: 000000' "$work/trace.clean" >/dev/null || exit 1
echo 'PASS: reproduced WAIT-to-PC-zero failure in isolated 64K image'
