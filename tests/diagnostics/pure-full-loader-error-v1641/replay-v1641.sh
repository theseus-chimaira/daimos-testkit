#!/bin/sh
# Test-only simulated one-shot failed FULL loader callback. The original
# callback first succeeds; change only returned AC1 in private SIMH VM.
set -eu
: "${PURE_FULL_LOADER_BUILD_V1641:?original v1638 mixed-PURE build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export PURE_FULL_BUILD_V1638="$PURE_FULL_LOADER_BUILD_V1641"
export PURE_FULL_PROFILE_V1640=loader-error
export PURE_FULL_TIMEOUT_V1638=${PURE_FULL_TIMEOUT_V1638:-770}
exec sh "$here/../pure-full-restore-v1638/replay-v1638.sh"
