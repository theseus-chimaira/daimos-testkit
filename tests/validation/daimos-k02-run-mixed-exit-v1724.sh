#!/bin/sh
# Booted PDP-6 independent PIPE MM_BUSY and regular VFS_SYNC refusal.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-run-mixed-exit-v1724.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
python3 "$self/daimos-k02-run-mixed-exit-v1724.py" \
    "$self/daimos-k02-run-pipe-exit-v1723.sh" \
    "$self/daimos-k02-run-pipe-exit-v1723.c" "$work" "$self"
sh -n "$work/daimos-k02-run-mixed-exit-v1724.generated.sh"
KEEP_TEST="${KEEP_TEST:-0}" sh \
    "$work/daimos-k02-run-mixed-exit-v1724.generated.sh"
