#!/bin/sh
# Source-authentic live 48K FAIL-NOMEM and exact MM owner rollback,
# then later compressed FULL reconstruction and all six child WAITs.
set -eu
: "${PURE_FULL_REFUSAL_BUILD_V1640:?original compressed-first build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export PURE_FULL_BUILD_V1638="$PURE_FULL_REFUSAL_BUILD_V1640"
export PURE_FULL_PROFILE_V1640=refusal
export PURE_FULL_TIMEOUT_V1638=${PURE_FULL_TIMEOUT_V1638:-880}
exec sh "$here/../pure-full-restore-v1638/replay-v1638.sh"
