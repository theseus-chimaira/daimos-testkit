#!/bin/sh
# Capture the *entry* to the original PDP-6 BRK MM path. This first
# verifies SIMH source-map breakpoint operation, before interpreting
# any later fatal/refusal path. No production image modification.
set -eu
: "${PURE_BRK_BUILD_V1615:?point to the preserved 48K PURE guest}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_BREAK_SITE_V1616=vm_space_brk_current
PURE_REPLAY_TIMEOUT_V1615=${PURE_REPLAY_TIMEOUT_V1615:-300}
export PURE_BREAK_SITE_V1616 PURE_REPLAY_TIMEOUT_V1615
exec sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
