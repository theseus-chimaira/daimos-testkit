#!/bin/sh
# Stop a real PDP-6 after the final BRK marker at the original Type-551
# DECtape search-wait instruction; inspect real state and timeout counter.
set -eu
: "${PURE_BRK_BUILD_V1615:?preserved 48K no-AUX PURE guest required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_TAPE_WAIT_BREAK_V1617=1
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-280}
export PURE_CONSOLE_STOP_V1616 PURE_TAPE_WAIT_BREAK_V1617
export PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
