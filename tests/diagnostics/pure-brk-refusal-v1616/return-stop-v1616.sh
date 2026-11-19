#!/bin/sh
# Console-triggered, source-verified post-vm_space_brk_current breakpoint.
# Install only after the final pressure marker, avoiding slow boot-wide
# CPU breakpoint checks. Inspect AC1/AC2 and MM before any fatal cleanup.
set -eu
: "${PURE_BRK_BUILD_V1615:?point to preserved 48K PURE guest}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_BRK_RETURN_V1616=1
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-320}
export PURE_CONSOLE_STOP_V1616 PURE_BRK_RETURN_V1616
export PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
