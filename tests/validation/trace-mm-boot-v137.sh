#!/bin/sh
# Build untouched disk media and capture the actual post-INIT machine state.
# Requires an isolated BUILD_ROOT so prior simulator writes never bias boot.
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
: "${PDP10_PREFIX:?}"
mem=${1:-64}
case $mem in 64|128) ;; *) echo 'supported memory: 64 or 128 K' >&2; exit 2 ;; esac
root="$TMPDIR/mm-boot-trace-v137-${mem}k-$$"
build="$root/build"
boot="$build/system/boot/pdp6"
mkdir -p "$root"
trap 'echo "Boot traces preserved at: $root"' EXIT
core=$((mem * 1024))
core_oct=$(printf '0%o' "$core")
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    COMPILER=gcc BOOT_PROFILE=lowmem ROOT=disk BOOT=dsk \
    BOOT_CORE_WORDS="$core_oct" SIMH_CPU_KWORDS="$mem" \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$build" \
    > "$root/build.log" 2>&1 || {
        tail -25 "$root/build.log" >&2
        exit 1
    }
slot=$(awk '$1=="proc_current_slot"{print $2}' "$boot/kcore.map")
high=$(awk '$1=="proc_high_slot"{print $2}' "$boot/kcore.map")
table=$(awk '$1=="proc_table"{print $2}' "$boot/kcore.map")
test -n "$slot" && test -n "$high" && test -n "$table"
sed "/^exit$/i\\
examine $slot\\
\\nexamine $high\\
\\nexamine $table\\
\\nexamine 0-7" "$boot/boot.ini" > "$root/trace.ini"
timeout 30 "${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}" "$root/trace.ini" \
    > "$root/trace.log" 2>&1 || :
tr -d '\r' < "$root/trace.log" > "$root/trace.clean"
grep -E 'MEM |INIT V1|WARNING|LOGIN:|HALT instruction|\?RT|Breakpoint' \
    "$root/trace.clean" || :
grep -F 'INIT V1' "$root/trace.clean" >/dev/null || exit 1
if grep -E 'HALT instruction|\?RT' "$root/trace.clean" >/dev/null; then
    echo 'REPRODUCED: simulator reached INIT, then halted' >&2
    exit 1
fi
echo 'No post-INIT halt observed during capture'
