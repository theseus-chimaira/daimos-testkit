#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-kcore-link-v1368"
mkdir -p "$work"
python3 -B "$testkit/tests/validation/d6codec-kcore-link-v1368/link-v1368.py" \
    "$DAIMOS_REPO" "$work"
