#!/bin/sh
# F07 24 live slots with actual swap backing and private stack watermarks.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${V1207_EVIDENCE_DIR:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-f07-mm-peak-host-v1203.py"
python3 "$self/daimos-f07-real-proc-host-v1205.py"
python3 "$self/daimos-f07-swapstack-host-v1207.py"
mode=${V1207_OOM_ENABLED:-1}
case "$mode" in
    0|1) ;;
    *) echo 'v1207: OOM policy must be 0 or 1' >&2; exit 2 ;;
esac
V1203_TEST_F07_PEAK=1 V1205_TEST_CONCURRENT=1 \
    V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1 \
    V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1 \
    V1160_EVIDENCE_DIR="$V1207_EVIDENCE_DIR" \
    V1075_TEST_OOM_ENABLED="$mode" \
    sh "$self/daimos-oom-requester-live-v1075.sh"
