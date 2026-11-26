#!/bin/sh
set -eu
: "${V1946_BUILD:?accepted v1945 physical guest build required}" "${V1946_PROVIDER_BUILD:?identical original provider build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
w=$(mktemp -d "$TMPDIR/pure-k08-pi6-physical-v1946.XXXXXX")
trap 'echo "v1946 physical evidence: $w"' EXIT
python3 "$here/replay-v1946.py" "$V1946_BUILD" "$w" "$PDP10_PREFIX" --timeout "${V1946_TIMEOUT:-1150}"
python3 "$here/verify-v1946.py" "$V1946_BUILD" "$w" "$PDP10_PREFIX"
python3 "$here/test-trace-v1946.py" "$V1946_BUILD" "$w" "$PDP10_PREFIX"
