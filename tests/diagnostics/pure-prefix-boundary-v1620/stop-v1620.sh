#!/bin/sh
# Physical PDP-6 opt-in PURE MM prefix-commit/rollback breakpoint.
# Reuses the original 48K TSFS no-AUX guest, with no image edits.
set -eu
: "${PURE_BRK_BUILD_V1615:?matching 48K PDP-6 TSFS PURE build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_PREFIX_BOUNDARY_V1620=1
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-360}
export PURE_CONSOLE_STOP_V1616 PURE_PREFIX_BOUNDARY_V1620
export PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
