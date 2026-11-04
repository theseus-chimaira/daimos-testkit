#!/bin/sh
# Booted RUN failure with exact real MM descriptor cause capture.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1116_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1116: invalid OOM mode' >&2; exit 2 ;;
esac
V1116_TEST_RUN_CAUSE=1 V1114_TEST_MM_SLOTS=1 \
 V1112_TEST_FAILED_RUN=1 V1110_TEST_NEGATIVES=1 \
 V1075_TEST_OOM_ENABLED="$mode" \
 sh "$self/daimos-oom-requester-live-v1075.sh"
