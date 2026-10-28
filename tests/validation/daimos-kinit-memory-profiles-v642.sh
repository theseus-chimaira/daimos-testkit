#!/bin/sh
# Lowmem image running at 48K/96K/256K, before any userspace execution.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-memory-v642.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v642 retained $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_KINIT_PROFILE_BUILD_V642:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
    image BUILD="$build" BOOT_PROFILE=lowmem ROOT=tape COMPILER=gcc \
    BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 KINIT_STACK_WATERMARK=1 \
    > "$work/build.log" 2>&1 || { tail -35 "$work/build.log" >&2; exit 1; }
entry=$(awk '$1 == "proc_boot_init" {print $2; exit}' "$build/kinit.map")
case "$entry" in ''|*[!0-7]*) echo 'missing proc_boot_init symbol' >&2; exit 1 ;; esac
for size in 48 96 256; do
    "$(dirname "$0")/../lib/daimos-simh-headless.sh" \
        "$build/boot.ini" "$work/base-$size.ini" "$((32900 + size))" "$((46900 + size))"
    awk -v size="$size" -v entry="$entry" '
        /^set cpu / { print "set cpu " size "k"; next }
        /^go 020$/ { print "break " entry }
        { print }
    ' "$work/base-$size.ini" > "$work/run-$size.ini"
    set +e
    (cd "$build" && TERM=dumb timeout -k 2s 30s \
        "$PDP10_PREFIX/bin/pdp6" "$work/run-$size.ini") > "$work/boot-$size.log" 2>&1
    rc=$?
    set -e
    [ "$rc" -eq 0 ] || { tail -60 "$work/boot-$size.log" >&2; exit 1; }
    grep -Fq "Breakpoint, PC: $entry " "$work/boot-$size.log"
    grep -Eq "^MEM[[:space:]]+$size K" "$work/boot-$size.log"
    grep -Eq 'DTC[[:space:]]+OK' "$work/boot-$size.log"
    grep -Eq 'DSK270[[:space:]]+OK' "$work/boot-$size.log"
    if grep -q 'INIT V1' "$work/boot-$size.log"; then
        echo "v642: userland started before breakpoint at $size K" >&2
        exit 1
    fi
    echo "v642: $size K lowmem KINIT-only PASS"
done
passed=1
echo 'daimos-kinit-memory-profiles-v642: PASS'
