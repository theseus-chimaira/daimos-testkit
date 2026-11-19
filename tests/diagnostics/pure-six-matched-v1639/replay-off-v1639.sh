#!/bin/sh
# Preserve original PURE-OFF physical MM B/A/Z after the same
# six-child+expected-seventh-refusal workload as accepted v1637.
set -eu
: "${PURE_OFF_BUILD_V1639:?source-matched 48K six-child OFF build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export PURE_CACHE_LOW_BUILD_V1636="$PURE_OFF_BUILD_V1639"
export PURE_CACHE_PROFILE_V1637=six-control-off
export PURE_CACHE_LOW_TIMEOUT_V1636=${PURE_CACHE_LOW_TIMEOUT_V1636:-620}
exec sh "$here/../pure-cache-low-v1636/replay-v1636.sh"
