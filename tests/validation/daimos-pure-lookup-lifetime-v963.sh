#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-pure-lookup-lifetime-v963.py" "$DAIMOS_REPO"
