#!/bin/sh
# Verify already-completed physical evidence without rebuilding the guest.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-backstore-coalesced-physical-v1503.py" --self-test
if [ "$#" -ne 2 ]; then
    echo 'usage: daimos-backstore-coalesced-physical-v1503.sh ADDRESSES SIMH.OUT' >&2
    exit 2
fi
python3 "$self/daimos-backstore-coalesced-physical-v1503.py" "$1" "$2"
