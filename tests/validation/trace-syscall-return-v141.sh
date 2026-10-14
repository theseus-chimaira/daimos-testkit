#!/bin/sh
# Isolate INIT's late user/syscall boundary before the PC-zero boot failure.
# This is a diagnostic reproducer, not successful boot acceptance.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
work="$TMPDIR/syscall-return-v141-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
mkdir -p "$work"
echo "Trace retained at $work"
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
wait=$(awk '$1=="proc_wait_status" {print $2}' "$boot/kcore.map")
syscall=$(awk '$1=="mach_syscall" {print $2}' "$boot/kcore.map")
save=$(awk '$1=="mach_syscall_save" {print $2}' "$boot/kcore.map")
slot=$(awk '$1=="proc_current_slot" {print $2}' "$boot/kcore.map")
test -n "$wait" && test -n "$syscall" && test -n "$save" && test -n "$slot"
# JRSTF @mach_syscall_save is 021 instructions (octal) after mach_syscall.
ret=$(printf '%o' "$((0$syscall + 021))")
{
    sed '/^go 020$/,$d' "$boot/boot.ini"
    printf 'break %s\ngo 020\nnobreak %s\nbreak %s\n' "$wait" "$wait" "$ret"
    # Stop before the observed final return. An early change in call count
    # cannot silently turn a failure reproducer into boot acceptance.
    i=0
    while test "$i" -lt 15; do
        printf 'go\nexamine %s\nexamine %s\nexamine 17\n' "$slot" "$save"
        i=$((i + 1))
    done
    printf 'nobreak %s\nbreak 0\ngo\n' "$ret"
    printf 'examine %s\nexamine %s\nexamine 17\nexit\n' "$slot" "$save"
} > "$work/trace.ini"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
    timeout 30 "${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}" "$work/trace.ini" \
    > "$work/trace.log" 2>&1 || :
tr -d '\r' < "$work/trace.log" > "$work/trace.clean"
grep -E 'INIT V1|Breakpoint|LOGIN:|HALT instruction' "$work/trace.clean" || :
grep -F "Breakpoint, PC: $wait" "$work/trace.clean" >/dev/null
grep -F "Breakpoint, PC: $(printf '%06o' "$((0$ret))")" \
    "$work/trace.clean" >/dev/null
grep -F 'Breakpoint, PC: 000000' "$work/trace.clean" >/dev/null
echo 'PASS: fresh-media syscall-return sequence reproduces PC-zero fault'
