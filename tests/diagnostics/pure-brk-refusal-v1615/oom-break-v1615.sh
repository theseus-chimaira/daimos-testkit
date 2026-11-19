#!/bin/sh
# Halt a preserved full 48K PDP-6 PURE guest at the REAL native
# BRK fatal OOM instruction, before process reaping or MM release.
set -eu
: "${PURE_BRK_BUILD_V1615:?point to tested v1615 physical boot directory}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_OOM_BREAK_V1615=1
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-420}
export PURE_OOM_BREAK_V1615 PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/replay-v1615.sh"
