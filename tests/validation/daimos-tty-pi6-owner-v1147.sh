#!/bin/sh
# C04: owner-side physical TTY/VM/u-area fault plus independent PI6 worker.
# All instrumentation is confined to the v969 disposable PDP-6 kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1124_TTY_VM_UAREA=1 DAIMOS_V1147_PI6_OWNER=1 \
    sh "$self/daimos-tty-exit-pin-live-v969.sh"
