#!/bin/sh
# Booted failed-RUN negative with OOM disabled or disposable enabled.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1112_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1112: invalid OOM mode' >&2; exit 2 ;;
esac
V1112_TEST_FAILED_RUN=1 V1110_TEST_NEGATIVES=1 \
 V1075_TEST_OOM_ENABLED="$mode" \
 sh "$self/daimos-oom-requester-live-v1075.sh"
