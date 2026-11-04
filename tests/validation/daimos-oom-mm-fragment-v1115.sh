#!/bin/sh
# Full 256K PDP-6 actual MM fragmentation and BRK cause regression.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1115_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1115: invalid OOM mode' >&2; exit 2 ;;
esac
V1115_TEST_MM_FRAGMENT=1 V1112_TEST_FAILED_RUN=1 \
 V1110_TEST_NEGATIVES=1 V1075_TEST_OOM_ENABLED="$mode" \
 sh "$self/daimos-oom-requester-live-v1075.sh"
