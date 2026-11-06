#!/bin/sh
# F07 high occupancy during live held-provider requester OOM. Test-only.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${V1204_EVIDENCE_DIR:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-f07-mm-peak-host-v1203.py"
python3 "$self/daimos-f07-mm-high-host-v1204.py"
mode=${V1204_OOM_ENABLED:-1}
case "$mode" in
    0|1) ;;
    *) echo 'v1204: require V1204_OOM_ENABLED=0 or 1' >&2; exit 2 ;;
esac
V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1 \
    V1150_TEST_HELD_PROVIDER=1 V1159_TEST_PROTECTED=1 \
    V1160_RELEASE_MEDIA=1 V1160_EVIDENCE_DIR="$V1204_EVIDENCE_DIR" \
    V1075_TEST_OOM_ENABLED="$mode" \
    sh "$self/daimos-oom-requester-live-v1075.sh"
