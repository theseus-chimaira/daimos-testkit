#!/bin/sh
# Monitor two physical writes to a formerly PACKED owner-2 descriptor
# after exact 48K no-AUX PURE commit entry. No kernel instrumentation.
set -eu
: "${PURE_BRK_BUILD_V1615:?matching full 48K PURE build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_PREFIX_FOLLOW_V1620=1
export PURE_PREFIX_FOLLOW_V1620
exec sh "$here/stop-v1620.sh"
