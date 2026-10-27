#!/bin/sh
# Native 32K TSFS root with disposable, explicitly provisioned DSK AUXST1.
# Boot reachability only: swap-out/in must be covered separately.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
work="$TMPDIR/daimos-tsfs-auxstore-positive-v493-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
build="$work/build"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BOOT_PROFILE=lowmem ROOT=tape COMPILER=gcc BUILD="$build" > "$work/build.log" 2>&1
mkauxstore --blank "$work/aux.dsk" --blocks 020000
mkauxstore -i "$work/aux.dsk" --d6fs-base 1 --d6fs-blocks 07000 \
    --d6fs-super-a 0 --d6fs-super-b 1 \
    --backstore-blocks 01000 --logstore-blocks 0 --cache-blocks 07777
mkauxstore --inspect "$work/aux.dsk" > "$work/inspect.log"
grep -q 'BACKSTORE 7001+1000' "$work/inspect.log"
sed "s|$build/disk/dsk0.dsk|$work/aux.dsk|g" \
    "$build/boot.ini" > "$build/positive-source.ini"
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$build/positive-source.ini" "$build/positive.ini" 32361 46361
(
    cd "$build"
    TERM=dumb timeout -k 2s 14s "$PDP10_PREFIX/bin/pdp6" positive.ini
) > "$work/native.log" 2>&1 || rc=$?
if [ "${rc:-0}" -ne 0 ] && [ "${rc:-0}" -ne 124 ]; then
    cat "$work/native.log" >&2
    exit 1
fi
grep -q 'DSK270.*OK' "$work/native.log"
grep -q 'INIT V1' "$work/native.log"
echo 'daimos-tsfs-auxstore-positive-v493: PASS (provisioned device boot; swap transaction not verified)'
