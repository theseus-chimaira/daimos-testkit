#!/bin/sh
# P0-D: preserve MM failure type and line-owner publication boundaries.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tty-mm-stage-v1093.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1093 evidence: $work"; fi' EXIT HUP INT TERM

sh "$self/daimos-tty-actual-mm-v897.sh"
sh "$self/daimos-tty-session-actual-mm-v968.sh"

for variant in collapse premature; do
    if DAIMOS_V1093_NEGATIVE="$variant" \
        sh "$self/daimos-tty-actual-mm-v897.sh" \
        > "$work/$variant.log" 2>&1; then
        echo "v1093: unsafe $variant release unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1093: typed MM_BUSY/-5 and MM_INVAL/-4, stable TTY owner, two unsafe mutants rejected PASS'
