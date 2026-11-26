#!/bin/sh
set -eu
: "${V1943_BUILD:?prepared disposable physical race image required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-k07-race-physical-v1943.XXXXXX")
trap 'echo "v1943 physical evidence: $work"' EXIT
python3 "$here/replay-v1943.py" "$V1943_BUILD" "$work" "$PDP10_PREFIX" --timeout "${V1943_TIMEOUT:-1150}"
python3 "$here/verify-v1943.py" "$V1943_BUILD" "$work"
python3 "$here/check-reel-v1944.py" "$V1943_BUILD/media/dtc3-home-v22.tap" \
    "$work/media/dtc3.tap" "$V1943_BUILD/../user/comp-v1638.dxr"
