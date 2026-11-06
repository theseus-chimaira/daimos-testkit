#!/bin/sh
# Native regression: swap exchange must preserve both executable backing slots.
set -eu
: "$DAIMOS_REPO" "$PDP10_PREFIX"
if [ -z "$DAIMOS_REPO" ] || [ -z "$PDP10_PREFIX" ]; then
    echo 'v1241: DAIMOS_REPO and PDP10_PREFIX required' >&2
    exit 2
fi
if [ -z "$TMPDIR" ]; then TMPDIR=$HOME/tmp; fi
export TMPDIR
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-backing-v1241.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

sh "$self/daimos-swap-exchange-data-v854.sh"

# Re-run against an isolated pre-fix source, never writing to production.
mkdir -p "$work/old/system/kernel/proc"
for name in fs mm storage; do
    ln -s "$DAIMOS_REPO/system/kernel/$name" \
        "$work/old/system/kernel/$name"
done
for name in proc_storage_runtime_v30.s proc_pure_backing_pdp6.s; do
    ln -s "$DAIMOS_REPO/system/kernel/proc/$name" \
        "$work/old/system/kernel/proc/$name"
done
git -C "$DAIMOS_REPO" show \
    856e2e89:system/kernel/proc/proc_swap_pdp6.s \
    > "$work/old/system/kernel/proc/proc_swap_pdp6.s"
# The old code must reach the positive transaction. Omit only the new
# pre-transfer A-backstop negative cases, because the old implementation
# lacked that validation and otherwise correctly triggers fail_entry.
cp "$self/daimos-swap-exchange-data-v854.sh" \
    "$work/daimos-swap-exchange-data-v854.sh"
cp "$self/daimos-test-crt0-v1.s" "$work/daimos-test-crt0-v1.s"
python3 - "$self/daimos-swap-exchange-data-v854.s" \
    "$work/daimos-swap-exchange-data-v854.s" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()
a = s.index(' ; v1241: an outgoing A with a dirty saved-backing')
b = s.index(' ; v824: A writable span starts', a)
Path(sys.argv[2]).write_text(s[:a] + s[b:])
PY
if DAIMOS_REPO="$work/old" \
    sh "$work/daimos-swap-exchange-data-v854.sh" \
    > "$work/old.log" 2>&1; then
    echo 'v1241: old missing-backing-publish code unexpectedly passed' >&2
    exit 1
fi
if ! grep -q '__test_exit: got 000000000025 expected 000000000000' \
        "$work/old.log"; then
    tail -40 "$work/old.log" >&2
    echo 'v1241: unexpected old-path failure code' >&2
    exit 1
fi
echo 'v1241: exact outgoing/incoming backing state and old-path mutant PASS'
