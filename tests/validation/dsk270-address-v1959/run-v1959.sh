#!/bin/sh
# Current source-linked native controller suite plus deterministic race.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
test "$#" = 1 || { echo "usage: $0 WORK" >&2; exit 2; }
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir "$1"
w=$(cd "$1" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
probe="$here/../dsk270-runtime-v1958/queue-v1958.py"
driver="$DAIMOS_REPO/system/kernel/drivers/dsk_io.s"
for mode in queue read silent; do
    python3 "$probe" "$DAIMOS_REPO" "$driver" "$w/$mode" "$mode"
done
for mode in confirm unsafe; do
    python3 "$here/force-race-v1959.py" "$driver" "$w/driver-$mode.s" "$mode"
    case "$mode" in confirm) unsafe=0;; unsafe) unsafe=1;; esac
    V1959_EXPECT_UNSAFE="$unsafe" python3 "$probe" "$DAIMOS_REPO" \
        "$w/driver-$mode.s" "$w/race-$mode" silent
done
