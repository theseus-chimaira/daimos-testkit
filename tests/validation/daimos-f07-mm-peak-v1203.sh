#!/bin/sh
# F07: atomic MM snapshot under genuine physical BRK OOM + held D6FS lease.
# Both physical-OOM policy modes use only disposable kernel copies.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-f07-mm-peak-host-v1203.py"
mode=${V1203_OOM_ENABLED:-1}
case "$mode" in
    0|1) ;;
    *) echo 'v1203: expected V1203_OOM_ENABLED=0 or 1' >&2; exit 2 ;;
esac
: "${V1203_EVIDENCE_DIR:?set unique versioned evidence directory}"
V1203_TEST_F07_PEAK=1 V1150_TEST_HELD_PROVIDER=1 \
    V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1 \
    V1160_EVIDENCE_DIR="$V1203_EVIDENCE_DIR" \
    V1075_TEST_OOM_ENABLED="$mode" \
    sh "$self/daimos-oom-requester-live-v1075.sh"
