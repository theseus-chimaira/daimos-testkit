#!/bin/sh
# Source-linked PDP-6 DTFS write and real cache-invalidate ABI regression.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-write-preserve-v1818.XXXXXX")
if [ "${DTFS_WRITE_PRESERVE_KEEP_V1818:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(x) for x in sys.argv[1:])
dtfs = (repo / "system/kernel/fs/dtfs_runtime.s").read_text()
cache = (repo / "system/kernel/storage/bcache_pdp6.s").read_text()


def section(source, start, finish):
    assert source.count(start) == 1, (start, source.count(start))
    tail = source.split(start, 1)[1]
    assert finish in tail, finish
    return start + tail.split(finish, 1)[0]


write = section(dtfs, "dtfs_dtc_write:\n",
                "; AC1=physical DTC unit, AC2=exact READ_SUSPECT")
invalidate = section(cache, "bcache_invalidate_all:\n",
                     "; void bcache_workspace_invalidate")
assert write.count("pushj   17,bcache_invalidate_all") == 1
assert write.count("pushj   17,dtfs_intent_mount_gate_v1561") == 1
assert "move    1,(17)" in write
assert "pop     17,3" in write
assert "pop     17,2" in write
assert "hrrz    4,bcache_state" in invalidate
source = (".text\n.globl dtfs_dtc_write\n"
          ".globl dtfs_dtc_write_jump\n"
          ".globl bcache_invalidate_all\n" + write + "\n" + invalidate)
(out / "production-v1818.s").write_text(source)

# An unsafe write-time reclaim must fail the raw DTC argument oracle.
mutant = source.replace("pushj   17,bcache_invalidate_all",
                        "pushj   17,bcache_reclaim", 1)
assert mutant != source
(out / "mutant-reclaim-v1818.s").write_text(mutant)

# The invalidator's AC1..AC3 preservation is an explicit production ABI.
mutant = source.replace("hrrz    4,bcache_state",
                        "movei   2,7\n        hrrz    4,bcache_state", 1)
assert mutant != source
(out / "mutant-clobber-v1818.s").write_text(mutant)
print("PASS v1818: extracted source and two ABI-breaking mutants")
PY

run_case()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 20 --workdir "$work/run-$name" \
        --name "dtfs-write-$name-v1818" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-write-preserve-v1818.s" \
        "$source" > "$work/$name.log" 2>&1
}

if ! run_case production "$work/production-v1818.s"; then
    tail -65 "$work/production.log" >&2
    echo 'FAIL v1818: production write ABI' >&2
    exit 1
fi
echo 'PASS v1818: production write preserves DTC unit/block/buffer'
for name in reclaim clobber; do
    if run_case "$name" "$work/mutant-$name-v1818.s"; then
        echo "FAIL v1818: accepted unsafe $name mutation" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/$name.log" || {
        tail -65 "$work/$name.log" >&2
        echo "FAIL v1818: $name mutation did not reach the native oracle" >&2
        exit 1
    }
    echo "PASS v1818: rejected $name mutation"
done
