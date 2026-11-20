#!/bin/sh
# Source-linked F07 retry bitmap repair after the two exact failures.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-f07-retry-native-v1713.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 - "$DAIMOS_REPO/system/kernel" "$self" "$work" <<'PY'
from pathlib import Path
import runpy
import shutil
import sys

root, tests, work = map(Path, sys.argv[1:])
kernel = work / 'kernel'
for rel in ('proc/proc_swap_pdp6.s', 'storage/backstore.s',
            'storage/backstore_entry_v484.s'):
    target = kernel / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / rel, target)
runpy.run_path(str(tests / 'daimos-k01-f07-deferred-inject-v1713.py'))[
    'inject'](kernel)
back = (kernel / 'storage/backstore.s').read_text()
start = 'backstore_free:\n'
end = 'daimos_v1494_free_original:\n'
assert back.count(start) == 1 and back.count(end) == 1
prelude = start + back.split(start, 1)[1].split(end, 1)[0]
tail = ('daimos_v1494_free_original:\n'
        '        jrst    backstore_free_original_v1713\n')
header = '.text\n.globl backstore_free\n'
(work / 'production.s').write_text(header + prelude + tail)
guards = (
    ('unsafe-transition', '        trne    4,0200000\n',
     '        trnn    4,0200000\n'),
    ('unsafe-prevm', '        tlnn    4,0100000\n',
     '        tlne    4,0100000\n'),
    ('unsafe-term', '        tlne    4,04                  ; deferred TERM still owned\n',
     '        tlnn    4,04                  ; unsafe inverted TERM\n'),
)
for name, old, new in guards:
    assert prelude.count(old) == 1, 'v1713 guard drift: ' + name
    (work / (name + '.s')).write_text(
        header + prelude.replace(old, new, 1) + tail)
PY

run()
{
    name=$1
    src=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-f07-retry-v1713-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-f07-retry-native-v1713.s" "$src" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -55 "$work/production.log" >&2
    exit 1
}
for name in unsafe-transition unsafe-prevm unsafe-term; do
    if run "$name" "$work/$name.s"; then
        echo "v1713: $name unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/$name.log" || {
        tail -50 "$work/$name.log" >&2
        exit 1
    }
done
echo 'K01 v1713: native PDP-6 real F07 third-free repair, exact run, pending TERM, three mutants PASS'
