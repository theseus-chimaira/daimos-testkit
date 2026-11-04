#!/bin/sh
# Physical OOM requester/witness followed by actual numeric PID reuse.
# OOM is enabled only in an isolated test kernel when requested.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1120_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1120: invalid isolated OOM mode' >&2; exit 2 ;;
esac
V1120_TEST_PID_REUSE=1 V1075_TEST_OOM_ENABLED="$mode" \
    sh "$self/daimos-oom-requester-live-v1075.sh"
