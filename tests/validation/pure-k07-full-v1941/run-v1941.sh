#!/bin/sh
# Reuse a source-built v1940-equivalent 48K guest, with private tapes.
set -eu
: "${V1941_BUILD:?source-built mixed plain/compressed 48K guest required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-k07-full-v1941.XXXXXX")
trap 'echo "v1941 physical evidence: $work"' EXIT
python3 "$here/test-verifier-v1941.py"
python3 "$here/replay-v1941.py" "$V1941_BUILD" "$work" "$PDP10_PREFIX" \
    --timeout "${V1941_TIMEOUT:-1150}" --children "${V1941_CHILDREN:-5}"
python3 "$here/verify-v1941.py" "$V1941_BUILD" "$work" "$PDP10_PREFIX" \
    --children "${V1941_CHILDREN:-5}"
