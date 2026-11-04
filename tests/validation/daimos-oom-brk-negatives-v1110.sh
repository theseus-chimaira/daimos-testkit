#!/bin/sh
# v1110: invalid and out-of-range BRK may not trigger requester OOM.
# Default disabled; set V1110_OOM_ENABLED=1 for isolated opt-in policy.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1110_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1110: invalid OOM gate' >&2; exit 2 ;;
esac
V1110_TEST_NEGATIVES=1 V1075_TEST_OOM_ENABLED="$mode" \
    sh "$self/daimos-oom-requester-live-v1075.sh"
