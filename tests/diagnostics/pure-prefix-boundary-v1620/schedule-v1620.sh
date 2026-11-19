#!/bin/sh
# Continue original full 48K PURE transaction across MM retype, unpin,
# READY_ONCE scheduler cursor publication and process-slot activation.
set -eu
: "${PURE_BRK_BUILD_V1615:?matching full 48K PURE build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_PREFIX_SCHED_V1620=1
export PURE_PREFIX_SCHED_V1620
exec sh "$here/follow-v1620.sh"
