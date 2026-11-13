#!/bin/sh
# Regression: KINIT must patch D6FS public (unit,sector,buffer) direct
# adapter calls through the fixed DSK270 encoder, not directly to raw MRES.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-d6fs-dsk-abi-v1545.XXXXXX")
if [ "${V1545_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" "$self" <<'PY'
from pathlib import Path
import re
import sys

repo, work, tests = [Path(x) for x in sys.argv[1:]]
src = (repo / 'system/kernel/modules/module_minit.c').read_text()
start = src.index('        /* Secondary direct D6FS mounts need')
end = src.index('        /* The per-mount direct adapter is also used', start)
snippet = src[start:end]

targets = [
    (7, 'dsk270_read_sector'),
    (11, 'dsk270_read_sector'),
    (8, 'dsk270_write_sector'),
    (12, 'dsk270_write_sector'),
]

def assert_binding(code, export, wrapper):
    regex = (r'minit_export\(name, base, %dU\),\s*'
             r'\(unsigned int\)\(unsigned long\)&%s\)' % (export, wrapper))
    assert len(re.findall(regex, code)) == 1, (export, wrapper)

for export, wrapper in targets:
    assert_binding(snippet, export, wrapper)
assert 'module_service_get(MODULE_SERVICE_DSK_READ_SECTOR)' in snippet
assert 'module_service_get(MODULE_SERVICE_DSK_WRITE_SECTOR)' in snippet
assert 'minit_export(name, base, 7U), read_addr' not in snippet
assert 'minit_export(name, base, 8U), write_addr' not in snippet
for export, wrapper in targets:
    old = ('minit_export(name, base, %dU),\n'
           '                    (unsigned int)(unsigned long)&%s)' %
           (export, wrapper))
    assert snippet.count(old) == 1
    changed = snippet.replace(old,
              ('minit_export(name, base, %dU), %s)' %
               (export, 'read_addr' if 'read' in wrapper else 'write_addr')))
    try:
        assert_binding(changed, export, wrapper)
    except AssertionError:
        print('PASS v1545: rejected raw-MRES patch for export %d' % export)
    else:
        raise AssertionError('accepted wrong DSK270 ABI binding')

fixture = (tests / 'daimos-d6fs-minit-dsk-abi-v1545.s').read_text()
assert fixture.count('movei   1,dsk270_read_sector') == 1
changed = fixture.replace('movei   1,dsk270_read_sector',
                          'movei   1,mres_service_v1545',1)
(work / 'mutant-raw-direct-v1545.s').write_text(changed)
print('PASS v1545: KINIT bindings and four wrong-ABI mutants rejected')
PY

run_case() {
    label=$1; source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 \
        --timeout 15 --workdir "$work/run-$label" \
        --name "dskabi-$label-v1545" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$DAIMOS_REPO/system/kernel/storage/fs_backing.s" \
        "$DAIMOS_REPO/system/kernel/drivers/dsk270.s" \
        > "$work/$label.log" 2>&1
}
if ! run_case correct "$self/daimos-d6fs-minit-dsk-abi-v1545.s"; then
    tail -50 "$work/correct.log" >&2; exit 1
fi
echo 'PASS v1545: real PDP-6 D6FS -> DSK270 -> encoded-MRES ABI'
if run_case mutant "$work/mutant-raw-direct-v1545.s"; then
    echo 'FAIL v1545: accepted wrong direct-to-MRES ABI' >&2
    exit 1
fi
echo 'PASS v1545: incorrect direct-to-MRES native execution rejected'
