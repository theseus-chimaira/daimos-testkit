#!/bin/sh
# v1097: actual PDP-6 MM u-area release ABI, including three unsafe mutants.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
sh "$self/daimos-uarea-ownership-v956.sh"
for mutant in collapse early base; do
    if DAIMOS_V1097_MUTANT="$mutant" \
        sh "$self/daimos-uarea-ownership-v956.sh" >/dev/null 2>&1; then
        echo "v1097: unsafe $mutant u-area release unexpectedly PASSED" >&2
        exit 1
    fi
done
echo 'v1097: exact -4/-5, bad-base rejection, idempotence and three unsafe mutants PASS'
