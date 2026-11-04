#!/bin/sh
# Boot physical MM descriptor saturation through a temporary syscall
# testing protocol, without modifying any production kernel file.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1114_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1114: invalid OOM mode' >&2; exit 2 ;;
esac
V1114_TEST_MM_SLOTS=1 V1112_TEST_FAILED_RUN=1 \
 V1110_TEST_NEGATIVES=1 V1075_TEST_OOM_ENABLED="$mode" \
 sh "$self/daimos-oom-requester-live-v1075.sh"
