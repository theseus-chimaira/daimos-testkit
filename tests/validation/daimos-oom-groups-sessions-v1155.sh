#!/bin/sh
# E08: boot two real foreign sessions and groups with STOP/CONT and PID reuse.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1155_E08=1 sh "$self/daimos-group-self-fatal-v979.sh"
