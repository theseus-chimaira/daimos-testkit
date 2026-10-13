#!/bin/sh
set -eu
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
cd "$repo"
python3 tests/host/d6codec-v039/compare-v039.py > "$TMPDIR/d6codec-v039-results.tsv" 2> "$TMPDIR/d6codec-v039-summary.txt"
cat "$TMPDIR/d6codec-v039-summary.txt"
