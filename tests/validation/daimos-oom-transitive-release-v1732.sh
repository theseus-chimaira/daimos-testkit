#!/bin/sh
# K03 source-linked transitive cleanup graph and unsafe mutation matrix.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the DAIMOS checkout}"
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k03-transitive-v1732.XXXXXX")
export V1283_PRODUCTION_OOM_DEFAULT=1
python3 "$self/daimos-oom-transitive-release-v1732.py" > "$work/positive.log"
for mode in file hup foreign vfs sync pipe tty vm owner discard dpystop \
    dtfsload mmgate
do
    if DAIMOS_V1087_NEGATIVE="$mode" python3 \
        "$self/daimos-oom-transitive-release-v1732.py" \
        > "$work/$mode.log" 2>&1
    then
        echo "v1732: unsafe mutation accepted: $mode" >&2
        exit 1
    fi
done
cat "$work/positive.log"
echo 'v1732: 13 unsafe mutations rejected PASS'
echo "v1732: logs $work"
