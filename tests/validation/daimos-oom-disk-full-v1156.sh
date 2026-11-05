#!/bin/sh
# E09: actual booted backing allocator exhaustion and nonfatal RAM BRK.
# Only the copied full PDP-6 kernel gets private observability selectors.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1156_OOM_ENABLED:-0}
case "$mode" in
    0|1) ;;
    *) echo 'v1156: invalid requester OOM mode' >&2; exit 2 ;;
esac
V1156_TEST_DISK_FULL=1 V1075_TEST_OOM_ENABLED="$mode" \
    sh "$self/daimos-oom-requester-live-v1075.sh"
