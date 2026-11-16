#!/bin/sh
# Reuse source-matched physical MM capture, but stop after the
# deliberate seventh RUN refusal and all six subsequent WAITs.
set -eu
: "${PURE_CACHE_PRESSURE_BUILD_V1637:?original 48K pressure build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export PURE_CACHE_LOW_BUILD_V1636="$PURE_CACHE_PRESSURE_BUILD_V1637"
export PURE_CACHE_PROFILE_V1637=six-packed
export PURE_CACHE_LOW_TIMEOUT_V1636=${PURE_CACHE_LOW_TIMEOUT_V1636:-560}
exec sh "$here/../pure-cache-low-v1636/replay-v1636.sh"
