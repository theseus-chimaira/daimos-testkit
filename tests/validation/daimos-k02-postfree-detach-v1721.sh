#!/bin/sh
# Real 256K PDP-6 backing-detach refusal after irreversible PROCESS MM free.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k02-postfree-detach-v1721.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 "$self/daimos-k02-postfree-detach-v1721.py" \
    "$self/daimos-fatal-exec-integration-v890.sh" \
    "$work/daimos-fatal-exec-integration-v1721.generated.sh" "$self"

# Use the established unmodified v890 user program, real VM/MM, FILE
# teardown and simulator harness. Only the copied kernel's backing detach
# entry receives the two test-only return-code failures and counters.
KEEP_TEST="${KEEP_TEST:-0}" sh \
    "$work/daimos-fatal-exec-integration-v1721.generated.sh"
