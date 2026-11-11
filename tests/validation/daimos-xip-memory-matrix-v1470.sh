#!/bin/sh
# v1470: real full-profile MEMFS XIP at 128K, 192K and 256K PDP-6 core.
# Lowmem deliberately lacks MEMFS and is not an XIP test configuration.
set -eu
: "${TMPDIR:?set TMPDIR}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

cpucheck=$(mktemp -d "$TMPDIR/daimos-xip-cpu-v1470.XXXXXX")
trap 'rm -rf "$cpucheck"' EXIT HUP INT TERM

sizes=${XIP_V1470_SIZES:-128 192 256}
for size in $sizes; do
    case "$size" in
        128) image_words=0400000 ;;
        192) image_words=0600000 ;;
        256) image_words=01000000 ;;
        *) echo "invalid v1470 RAM profile: $size" >&2; exit 2 ;;
    esac
    # Open SIMH previously advertised 196K instead of 192K and silently
    # ignored 'set cpu 192k', leaving the default 256K active. Fail before
    # any expensive guest build if the requested physical size is rejected.
    {
        printf 'set cpu %sk\n' "$size"
        printf 'show cpu\nexit\n'
    } > "$cpucheck/cpu-$size.ini"
    "$PDP10_PREFIX/bin/pdp6" "$cpucheck/cpu-$size.ini" \
        > "$cpucheck/cpu-$size.out" 2>&1
    if grep -Eq 'SIM-ERROR|Non-existent parameter' "$cpucheck/cpu-$size.out" ||
        ! grep -Eq "^[[:space:]]+${size}KW" "$cpucheck/cpu-$size.out"; then
        cat "$cpucheck/cpu-$size.out" >&2
        echo "FAIL: PDP6 simulator does not accept ${size}K core" >&2
        exit 1
    fi
    printf '\n=== v1470: physical %sK PDP-6, full MEMFS profile ===\n' "$size"
    XIP_V1470_BOOT_CORE_WORDS="$image_words" \
    XIP_V1470_SIMH_CPU_KWORDS="$size" \
    XIP_V1469_WORK="${XIP_V1470_WORK_PREFIX:-$TMPDIR/daimos-xip-memory-v1470}-$size" \
    XIP_V1469_KEEP="${XIP_V1470_KEEP:-0}" \
    sh "$self/daimos-xip-launch-v1469.sh"
done
printf 'PASS v1470: full-profile privileged XIP lifecycle for %sK profile(s)\n' "$sizes"
