#!/bin/sh
# Run the production PDP-6 MM regression fixtures in deterministic order.
# Keep tests in daimos-testkit; do not change the production MM for testing.
set -eu
: "${DAIMOS_REPO:?Set DAIMOS_REPO to the DAIMOS checkout under test}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR DAIMOS_REPO
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
count=0
for script in $(find "$here" -name 'run-v*.sh' -type f | LC_ALL=C sort); do
    printf 'MM native test: %s\n' "${script#"$here"/}"
    sh "$script"
    count=$((count + 1))
done
test "$count" -eq 15
printf 'PASS: %s PDP-6 MM regression scripts\n' "$count"
