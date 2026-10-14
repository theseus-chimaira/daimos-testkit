#!/bin/sh
# Boot the default compressed LOGIN image with Stage1-shared D6LZ in KCORE.
# This tests the resolved PC-zero decoder link regression, not interactive
# login acceptance (which is tested independently on the DCS terminal).
set -eu
: "${DAIMOS_REPO:?Set DAIMOS_REPO}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"
: "${TMPDIR:?Set TMPDIR}"
size=${1:-64}
case $size in
    64) core=0200000 ;;
    128) core=0400000 ;;
    *) echo 'usage: daimos-d6lz-core-boot-v142.sh [64|128]' >&2; exit 2 ;;
esac
tag="d6lz-core-boot-v142-${size}k-$$"
work="$TMPDIR/$tag"
build="$work/build"
boot="$build/system/boot/pdp6"
mkdir -p "$work"
printf 'Boot logs: %s\n' "$work"
port=$((23000 + ($$ % 8000)))
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BOOT_PROFILE=lowmem ROOT=disk BOOT=dsk COMPILER=gcc \
    BOOT_CORE_WORDS="$core" SIMH_CPU_KWORDS="$size" \
    SIMH_DCS0_PORT="$port" SIMH_GE0_PORT="$((port + 10000))" \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$build" \
    > "$work/build.log" 2>&1 || {
        tail -30 "$work/build.log" >&2
        exit 1
    }
sh "$(dirname "$0")/check-d6lz-fixed-placement-v142.sh" "$boot/kcore.map"
set +e
SDL_VIDEODRIVER=dummy TERM=dumb timeout 18 \
    "${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}" "$boot/boot.ini" \
    > "$work/boot.log" 2>&1
rc=$?
set -e
tr -d '\r' < "$work/boot.log" > "$work/boot.clean"
for milestone in 'DAIMON' 'MEMFS' 'D6FS' 'INIT V1'; do
    if ! grep -F "$milestone" "$work/boot.clean" >/dev/null; then
        tail -40 "$work/boot.clean" >&2
        echo "$tag: missing $milestone" >&2
        exit 1
    fi
done
if [ "$rc" -ne 124 ] || grep -E 'HALT instruction|\?RT|MEMFS NOT MOUNTED' "$work/boot.clean" >/dev/null; then
    tail -40 "$work/boot.clean" >&2
    echo "$tag: compressed LOGIN boot regressed (simulator status $rc)" >&2
    exit 1
fi
echo "$tag: PASS (decoder fixed at 000060; INIT survives 18 seconds)"
