#!/bin/sh
# Native C89 FILE diagnostic ABI check against current kernel header.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-teardown-detail-count-v952.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
includes="-I$DAIMOS_REPO/tools/host"
for d in boot core drivers fs ipc mm modules proc storage; do
    includes="$includes -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
${CC:-cc} -std=c89 -Wall -Wextra -Werror $includes \
    "$self/daimos-teardown-detail-count-v952.c" -o "$work/test"
"$work/test"
echo 'v952: teardown FILE count does not overlap first-FD or error PASS'
