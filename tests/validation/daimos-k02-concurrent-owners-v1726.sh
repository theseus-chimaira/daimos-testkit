#!/bin/sh
# Booted PDP-6: simultaneous D6FS and PIPE owners in distinct RUN children.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-concurrent-owners-v1726.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
python3 "$self/daimos-k02-concurrent-owners-v1726.py" "$work" "$self"
sh -n "$work/daimos-k02-concurrent-owners-v1726.generated.sh"
KEEP_TEST="${KEEP_TEST:-0}" sh \
    "$work/daimos-k02-concurrent-owners-v1726.generated.sh"
