#!/bin/sh
# Correct the scoped native/event diagnostic SKIPE/SKIPN polarity.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-branch-guard-v1502.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1502 work: $work"; fi' EXIT HUP INT TERM
mkdir -p "$work/kernel/proc" "$work/kernel/storage"
cp "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
   "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" \
   "$work/kernel/proc/"
cp "$DAIMOS_REPO/system/kernel/storage/backstore.s" \
   "$DAIMOS_REPO/system/kernel/storage/backstore_entry_v484.s" \
   "$work/kernel/storage/"
python3 "$self/daimos-backstore-term-branch-v1499.py" "$work/kernel"

python3 - "$work/kernel/proc/proc_pdp6.s" \
    "$self/daimos-branch-guard-v1502.s" "$work/guard.s" <<'PY'
from pathlib import Path
import sys

proc, fixture, output = map(Path, sys.argv[1:])
text = proc.read_text()
anchor = 'proc_event_fatal_other_defer_term_v926:\n'
if text.count(anchor) != 1:
    raise AssertionError('v1502: original scoped event branch moved')
lines = text.split(anchor, 1)[1].splitlines()
guard = '\n'.join(lines[:2]) + '\n'
expected = ('        skipe   daimos_v1499_active\n'
            '        aos     daimos_v1499_deferred\n')
if guard != expected:
    raise AssertionError('v1502: injected event guard is not SKIPE')
guard = (guard.replace('daimos_v1499_active', '__active')
              .replace('daimos_v1499_deferred', '__count'))
template = fixture.read_text()
if template.count('; INSERT_GUARD_V1502\n') != 3:
    raise AssertionError('v1502: oracle missing three guard sites')
output.write_text(template.replace('; INSERT_GUARD_V1502\n', guard))
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 80000 --timeout 15 \
    --workdir "$work/pass" --name scoped-branch-v1502 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/guard.s" \
    > "$work/pass.log" 2>&1 || {
        tail -45 "$work/pass.log" >&2
        exit 1
    }
echo 'PASS v1502: real PDP-6 SKIPE increments only while active'

# Reintroducing the initial wrong SKIPN must fail this exact oracle.
python3 - "$work/guard.s" "$work/wrong.s" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()
old = '        skipe   __active\n'
if s.count(old) != 3:
    raise AssertionError('v1502: expected three active guards')
Path(sys.argv[2]).write_text(s.replace(old, '        skipn   __active\n'))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 80000 --timeout 15 \
    --workdir "$work/wrong" --name inverted-branch-v1502 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/wrong.s" \
    > "$work/wrong.log" 2>&1; then
    echo 'FAIL v1502: inverted diagnostic guard falsely passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/wrong.log" || {
    echo 'FAIL v1502: negative control did not reach test assertion' >&2
    tail -40 "$work/wrong.log" >&2
    exit 1
}
echo 'PASS v1502: prior inverted SKIPN observer rejected'
