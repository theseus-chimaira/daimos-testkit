#!/bin/sh
# Sequential physical TTY, process-VM and post-VM u-area MM_BUSY.
# The test kernel is disposable; production OOM remains OFF.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1124_TTY_VM_UAREA=1 \
    sh "$self/daimos-tty-exit-pin-live-v969.sh"
