#!/bin/sh
set -eu
: "${V1945_BUILD:?prepared v1945 source loss fixture required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
w=$(mktemp -d "$TMPDIR/pure-k07-loss-physical-v1945.XXXXXX")
trap 'echo "v1945 physical evidence: $w"' EXIT
python3 "$here/replay-v1945.py" "$V1945_BUILD" "$w" "$PDP10_PREFIX" --timeout "${V1945_TIMEOUT:-1150}"
python3 "$here/verify-v1945.py" "$V1945_BUILD" "$w" "$PDP10_PREFIX"
python3 "$here/test-trace-v1945.py" "$V1945_BUILD" "$w" "$PDP10_PREFIX"
