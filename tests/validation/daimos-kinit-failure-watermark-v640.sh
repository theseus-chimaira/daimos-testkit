#!/bin/sh
# Native invalid-root HALT must record bounded KINIT stack use.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-fail-v640.XXXXXX")
passed=0
cleanup()
{
    if [ "$passed" -eq 1 ]; then
        rm -rf "$work"
    else
        echo "v640: diagnostics retained at $work" >&2
    fi
}
trap cleanup EXIT HUP INT TERM
build=${DAIMOS_KINIT_WATERMARK_BUILD_V639:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s \
    -C "$DAIMOS_REPO/system/boot/pdp6" image BUILD="$build" \
    BOOT_PROFILE=lowmem ROOT=tape COMPILER=gcc BOOT_CORE_WORDS=0140000 \
    SIMH_CPU_KWORDS=48 KINIT_STACK_WATERMARK=1 \
    > "$work/build.log" 2>&1 || {
        tail -35 "$work/build.log" >&2
        exit 1
    }
address=$(awk '$1 == "kinit_stack_highwater" { print $2; exit }' "$build/kcore.map")
case "$address" in ''|*[!0-7]*) echo 'missing watermark address' >&2; exit 1 ;; esac
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$build/boot.ini" "$work/headless.ini" 32829 46829
# Unrecognized root class 7 cannot select any supported root. Read the
# diagnostic word after the CPU executes its fatal HALT, not while running.
awk -v address="$address" '
    /^deposit SW / { print "deposit SW 7"; next }
    /^exit$/ { print "examine " address }
    { print }
' "$work/headless.ini" > "$work/failure.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 25s \
    "$PDP10_PREFIX/bin/pdp6" "$work/failure.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -60 "$work/boot.log" >&2; exit 1; }
grep -q 'HALT instruction' "$work/boot.log"
grep -q 'MEM[[:space:]]\+48 K' "$work/boot.log"
# SIMH prints its own minimal-width octal address and twelve-digit word.
short=$(printf '%o' "$((0$address))")
value=$(awk -v address="$short" '$1 == address ":" { print $2; exit }' "$work/boot.log")
case "$value" in ''|*[!0-7]*) echo 'no valid recorded high-water value' >&2; exit 1 ;; esac
used=$((0$value))
if [ "$used" -le 0 ] || [ "$used" -ge "$((0600))" ]; then
    echo "v640: invalid stack high-water: $value" >&2
    exit 1
fi
passed=1
printf 'daimos-kinit-failure-watermark-v640: PASS (fatal root HALT; high-water %o octal / %d words)\n' "$used" "$used"
