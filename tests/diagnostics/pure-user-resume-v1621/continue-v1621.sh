#!/bin/sh
# Follow v1620 proved MM retype, unpin and READY_ONCE/current writes.
# Continue actual PDP-6 CPU after slot-2 selection in two bounded steps.
set -eu
: "${PURE_BRK_BUILD_V1615:?original 48K PURE build required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_USER_CONTINUE_V1621=1
export PURE_USER_CONTINUE_V1621
exec sh "$here/../pure-prefix-boundary-v1620/schedule-v1620.sh"
