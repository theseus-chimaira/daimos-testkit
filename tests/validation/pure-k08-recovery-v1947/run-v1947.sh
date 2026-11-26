#!/bin/sh
# Unchanged production physical images; do not shorten tape search timeout.
set -eu
: "${V1946_BUILD:?accepted v1945 physical guest build required}" "${V1946_PROVIDER_BUILD:?identical original provider build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR V1946_PROVIDER_BUILD
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
prior="$here/../pure-k08-pi6-v1946"
w=$(mktemp -d "$TMPDIR/pure-k08-recovery-v1947.XXXXXX")
trap 'echo "v1947 physical evidence: $w"' EXIT
python3 "$prior/replay-v1946.py" "$V1946_BUILD" "$w" "$PDP10_PREFIX" --timeout "${V1947_TIMEOUT:-1150}"
python3 "$prior/test-trace-v1946.py" "$V1946_BUILD" "$w" "$PDP10_PREFIX"
python3 "$here/verify-v1947.py" "$V1946_BUILD" "$w" "$PDP10_PREFIX" --mutants
