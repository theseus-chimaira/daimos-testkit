#!/bin/sh
# Use SIMH's console EXPECT (not a per-instruction CPU breakpoint) to
# capture live MM exactly after the BRK request marker and before BRK.
# It is a diagnostic, NOT a successful RAW reclaim assertion.
set -eu
: "${PURE_BRK_BUILD_V1615:?point to preserved 48K PURE guest}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-240}
export PURE_CONSOLE_STOP_V1616 PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
