#!/bin/sh
# Inspect the actual resident scheduler trampoline targets on a real
# opt-in no-AUX PDP-6, without changing production memory.
set -eu
: "${PURE_BRK_BUILD_V1615:?point to matching physical 48K PURE build}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_MRES_PROBE_V1617=1
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-230}
export PURE_CONSOLE_STOP_V1616 PURE_MRES_PROBE_V1617
export PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
