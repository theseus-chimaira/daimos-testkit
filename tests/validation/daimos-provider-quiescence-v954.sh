#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-provider-quiescence-v954.py" "$DAIMOS_REPO"
