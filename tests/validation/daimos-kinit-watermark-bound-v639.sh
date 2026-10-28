#!/bin/sh
# Native watermark-enabled PDP-6 boot, with the upper stack word in core.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-watermark-v639.XXXXXX")
build=${DAIMOS_KINIT_WATERMARK_BUILD_V639:-$work/build}
boot="$build"
passed=0
cleanup()
{
    if [ "$passed" -eq 1 ]; then
        rm -rf "$work"
    else
        echo "v639: retained failed test data at $work" >&2
    fi
}
trap cleanup EXIT HUP INT TERM
PATH="$PDP10_PREFIX/bin:$PATH" make -s \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" BOOT_PROFILE=lowmem ROOT=tape COMPILER=gcc \
    BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 \
    KINIT_STACK_WATERMARK=1 > "$work/build.log" 2>&1 || {
    tail -35 "$work/build.log" >&2
    exit 1
}
grep -q '^kinit_stack_watermark_begin[[:space:]]' "$boot/kinit.map"
grep -q '^kinit_stack_watermark_measure[[:space:]]' "$boot/kinit.map"
end=$(awk '$1 == "__kinit_image_end" {print $2; exit}' "$boot/kinit.map")
case "$end" in ''|*[!0-7]*) echo 'invalid KINIT image end' >&2; exit 1 ;; esac
[ "$((0$end))" -le "$((0140000 - 0600))" ] || {
    echo 'KINIT image exceeds instrumented 48K stack limit' >&2
    exit 1
}
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$boot/boot.ini" "$work/boot.headless.ini" 32739 46739
set +e
(cd "$boot" && TERM=dumb timeout -k 2s 40s \
    "$PDP10_PREFIX/bin/pdp6" "$work/boot.headless.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ]; then
    tail -70 "$work/boot.log" >&2
    exit 1
fi
grep -Eq '^MEM[[:space:]]+48 K' "$work/boot.log"
grep -q 'INIT V1' "$work/boot.log"
passed=1
echo 'daimos-kinit-watermark-bound-v639: PASS (48K watermark boot)'
