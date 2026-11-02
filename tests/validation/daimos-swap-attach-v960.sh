#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-attach-v960.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
includes="-I$DAIMOS_REPO/tools/host"
for d in boot core drivers fs ipc mm modules proc storage; do
    includes="$includes -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
${CC:-cc} -std=c89 -Wall -Wextra -Werror $includes \
    "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" \
    "$self/daimos-swap-attach-v960.c" -o "$work/check"
"$work/check"
