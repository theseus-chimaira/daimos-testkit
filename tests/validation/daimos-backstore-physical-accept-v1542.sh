#!/bin/sh
# Validate retained full-guest Type-236 PI2 evidence without rerunning PDP-6.
# Usage: script ABSOLUTE_GUEST_DIRECTORY. Rechecks original linked KCORE,
# real post-HALT memory and selected descriptor's physical PI2 handling.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
test "$#" -eq 1 || { echo 'usage: script GUEST_DIRECTORY' >&2; exit 2; }
guest=$1
test -f "$guest/build/system/boot/pdp6/kcore.map" || {
    echo 'v1542: missing actual linked fixed KCORE map' >&2
    exit 1
}
python3 "$self/daimos-backstore-physical-verify-v1542.py" --self-test \
    "$guest/build/system/boot/pdp6/kcore.map" \
    "$guest/simh.out" "$guest/simh.out.raw-v1306.log" \
    "$guest/source/system/kernel/fs/fs_mres.s" \
    "$guest/source/system/kernel/drivers/drm236_io.s" \
    "$guest/simh.out.raw-v1306.log"
echo 'PASS v1542: retained physical guest fully reverified'
