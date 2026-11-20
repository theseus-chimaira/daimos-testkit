#!/bin/sh
# Full PDP-6: permanently refused D6FS session owner and fatal lowmem EXEC.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-session-exec-v1729.XXXXXX")
KEEP_TEST=${KEEP_TEST:-0}
trap 'if [ "$KEEP_TEST" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
python3 "$self/daimos-k02-session-exec-v1729.py" "$work" "$self"
sh -n "$work/daimos-k02-session-exec-v1729.generated.sh"
KEEP_TEST="$KEEP_TEST" sh "$work/daimos-k02-session-exec-v1729.generated.sh"
