#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-swap-record-contract-v959.py" "$DAIMOS_REPO"
