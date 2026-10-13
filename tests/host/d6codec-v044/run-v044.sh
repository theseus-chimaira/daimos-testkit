#!/bin/sh
set -eu
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
cd "$repo"
python3 tests/host/d6codec-v044/ablate-v044.py > "$TMPDIR/d6codec-v044-results.tsv"
cat "$TMPDIR/d6codec-v044-results.tsv"
