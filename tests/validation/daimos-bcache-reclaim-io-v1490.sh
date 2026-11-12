#!/bin/sh
# Source-link real BCACHE and DTC veneers; replace physical hardware only.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-bcache-reclaim-io-v1490.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

# Export the cache-private ownership words only in the isolated test object;
# do not publish these addresses as a production KCORE ABI.
python3 - "$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s" \
    "$work/cache-v1490.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
if source.count('bcache_state:') != 1 or \
        source.count('bcache_workspace_tag:') != 1:
    raise ValueError('cache-private ownership layout changed')
Path(sys.argv[2]).write_text(
    '.globl bcache_state\n.globl bcache_workspace_tag\n' + source)
PY

python3 - "$DAIMOS_REPO/system/kernel/fs/dtfs_runtime.s" \
    "$work/dtc-v1490.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start = 'dtfs_dtc_read:\n'
end = '\n        .if DTFS_ENABLE_FOREIGN'
if source.count(start) != 1:
    raise ValueError('ambiguous production DTC read veneer')
tail = source.split(start, 1)[1]
if end not in tail:
    raise ValueError('missing DTC veneer end')
code = start + tail.split(end, 1)[0]
for label, replacement in (
        ('dtfs_dtc_read_jump', 'mock_dtc_read_v1490'),
        ('dtfs_dtc_write_jump', 'mock_dtc_write_v1490')):
    old = label + ':\n        jrst    0'
    if code.count(old) != 1:
        raise ValueError('physical DTC patch slot moved: ' + label)
    code = code.replace(old, label + ':\n        jrst    ' + replacement, 1)
Path(sys.argv[2]).write_text(
    '.text\n.globl dtfs_dtc_read\n.globl dtfs_dtc_write\n' + code + '\n')
PY

run_guest() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 \
        --timeout 25 --workdir "$work/$label" --name "$label" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$work/dtc-v1490.s" \
        "$self/daimos-bcache-reclaim-io-v1490.s" \
        > "$work/$label.log" 2>&1
}

if ! run_guest fixed "$work/cache-v1490.s"; then
    tail -65 "$work/fixed.log" >&2
    exit 1
fi
echo 'PASS v1490: DTC write retains raw unit/block/buffer and invalidates cache'
echo 'PASS v1490: refused MM free leaves slab owned but no stale valid tags'

# Executable negative control: resurrect the old reclaim-before-raw-write
# operation and require the original test to reject the bad DTC register ABI.
python3 - "$work/dtc-v1490.s" "$work/dtc-unsafe-v1490.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        push    17,1                   ; preserve physical unit across I/O\n'
       '        pushj   17,bcache_invalidate_all\n'
       '        pushj   17,dtfs_dtc_write_jump')
if source.count(old) != 1:
    raise ValueError('DTC invalidation gate missing')
Path(sys.argv[2]).write_text(source.replace(
    old, '        push    17,1                   ; preserve physical unit across I/O\n'
         '        pushj   17,bcache_reclaim\n'
         '        pushj   17,dtfs_dtc_write_jump', 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 300000 \
    --timeout 25 --workdir "$work/unsafe" --name unsafe-v1490 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/cache-v1490.s" \
    "$work/dtc-unsafe-v1490.s" \
    "$self/daimos-bcache-reclaim-io-v1490.s" \
    > "$work/unsafe.log" 2>&1; then
    echo 'FAIL v1490: old DTC reclaim-before-write mutation was accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/unsafe.log" || {
    tail -50 "$work/unsafe.log" >&2
    echo 'FAIL v1490: mutation failure was not the expected assertion' >&2
    exit 1
}
echo 'PASS v1490: old reclaim-before-write corruption rejected'

# A second mutation preserves the DTC API fix but discards the mandatory
# invalidate-on-refused-free step. It must fail at the tag integrity checks.
python3 - "$work/cache-v1490.s" \
    "$work/cache-unsafe-v1490.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        pushj   17,bcache_invalidate_all\n'
       '        hrrz    010,bcache_state')
if source.count(old) != 1:
    raise ValueError('cache reclaim invalidation gate missing')
Path(sys.argv[2]).write_text(source.replace(old,
    '        hrrz    010,bcache_state', 1))
PY
if run_guest unsafe-tags "$work/cache-unsafe-v1490.s"; then
    echo 'FAIL v1490: refused MM free with stale tags was accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/unsafe-tags.log" || {
    tail -50 "$work/unsafe-tags.log" >&2
    echo 'FAIL v1490: stale-tag mutation failure was not the assertion' >&2
    exit 1
}
echo 'PASS v1490: stale-cache-on-refused-free mutation rejected'
