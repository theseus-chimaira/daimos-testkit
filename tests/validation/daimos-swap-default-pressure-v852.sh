#!/bin/sh
# v852: acceptance using the production PDP-6 drum layout, with no
# backstore-capacity override and no added simulator breakpoints.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${DAS_REPO:?}"
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export TMPDIR DAIMOS_MM_TRACE_KEEP=1
exec sh "$self/daimos-mm-swap-scheduler-v669.sh"
