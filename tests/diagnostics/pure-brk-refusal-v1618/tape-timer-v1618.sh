#!/bin/sh
# Sample Type-551 search state twice in ONE physical PDP-6 run.
# After the source-checked RBN-search instruction breakpoint, remove
# it and advance the live SIMH CPU by bounded simulated microseconds.
# Inspect real APR line-clock counter and tape module BSS in between.
set -eu
: "${PURE_BRK_BUILD_V1615:?preserved 48K no-AUX PURE build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_TAPE_WAIT_BREAK_V1617=1
PURE_DTC_ADVANCE_US_V1618=${PURE_DTC_ADVANCE_US_V1618:-3000000}
PURE_DTC_WINDOWS_V1618=${PURE_DTC_WINDOWS_V1618:-2}
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-320}
export PURE_CONSOLE_STOP_V1616 PURE_TAPE_WAIT_BREAK_V1617
export PURE_DTC_ADVANCE_US_V1618 PURE_DTC_WINDOWS_V1618
export PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
