#!/bin/sh
# 256K PDP-6: PIPE MM_BUSY plus refused D6FS provider SYNC under MRES lease.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-run-provider-lease-v1725.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM

python3 "$self/daimos-k02-run-provider-lease-v1725.py" "$work" "$self"
sh -n "$work/daimos-k02-run-provider-lease-v1725.generated.sh"
KEEP_TEST="${KEEP_TEST:-0}" sh \
    "$work/daimos-k02-run-provider-lease-v1725.generated.sh"
