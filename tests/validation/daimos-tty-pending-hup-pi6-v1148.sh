#!/bin/sh
# C04 integrated test: pending same-session HUP on a private owner stack,
# physically pinned TTY/VM/u-area, live PI6 and independent session.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1124_TTY_VM_UAREA=1 DAIMOS_V1147_PI6_OWNER=1 \
    DAIMOS_V1148_PENDING_HUP=1 \
    sh "$self/daimos-tty-exit-pin-live-v969.sh"
