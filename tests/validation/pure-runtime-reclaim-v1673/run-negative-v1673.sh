#!/bin/sh
# Execute physical evidence corruptions against the SAME positive MM oracle.
# Never edit production kernel or alter the original source-built guest.
set -eu
: "${DAIMOS_REPO:?DAIMOS source tree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
if [ "$#" -ne 4 ]; then
    echo 'usage: run-negative-v1673.sh strict-console.clean fixture.map kcore.map accepted-report.json' >&2
    exit 2
fi
console=$1
fixture=$2
coremap=$3
accepted=$4
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1673-reclaim-negative.XXXXXX")
keep=${KEEP_TEST:-0}
trap 'if [ "$keep" = 1 ]; then echo "v1673 negative evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
for file in "$console" "$fixture" "$coremap" "$accepted"; do
    test -s "$file"
done
python3 "$here/measure-v1673.py" "$fixture" "$coremap" "$console" 48 \
    "$work/original-remeasured.json" > "$work/original-pass.log"

python3 - "$here/measure-v1673.py" "$console" "$coremap" \
    "$accepted" "$work" <<'PY'
import importlib.util
import json
import re
import sys
from pathlib import Path

module_path, source_path, coremap, report_path, root = sys.argv[1:]
root = Path(root)
source = Path(source_path).read_text(encoding='ascii')
spec = importlib.util.spec_from_file_location('v1673physical', module_path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
# The actual fixture map is needed only for positive stage splitting.
phase = 'B'
head = 'V1673 HOLD ' + phase
end = 'V1673 RELEASE ' + phase
if source.count(head) != 1 or source.count(end) != 1:
    raise SystemExit('v1673: ambiguous actual physical B phase')
before, rest = source.split(head, 1)
between, after = rest.split(end, 1)
words = {}
for address, value in re.findall(r'^(?:sim> )?([0-7]{3,7}):\s+([0-7]{12})\s*$',
                                 between, re.M):
    addr = int(address, 8)
    if addr in words:
        raise SystemExit('v1673: duplicate native physical word')
    words[addr] = int(value, 8)

def symbol(name):
    return m.lookup(coremap, name)


def emit(name, addr, value):
    octal = '%o' % addr
    expr = r'(?m)^((?:sim> )?0*' + octal + r':\s+)[0-7]{12}\s*$'
    matches = list(re.finditer(expr, between))
    if len(matches) != 1:
        raise SystemExit('v1673: no unique original MM mutation word %o' % addr)
    changed = re.sub(expr,
                     lambda found: found.group(1) + ('%012o' % value),
                     between, count=1)
    (root / (name + '.log')).write_text(before + head + changed + end + after,
                                      encoding='ascii')

storage = words[symbol('proc_storage_runtime_v29')]
mode_address = storage + 2 // 18
mode = words[mode_address]
if ((mode >> 4) & 3) != 2:
    raise SystemExit('v1673: real B slot2 not in PACKED mode')
emit('unsafe-storage-mode', mode_address, mode & ~(3 << 4))

extents = symbol('mm_extents')
count = words[symbol('mm_extent_count')]
meta_addr = None
for i in range(count):
    address = extents + 2 * i + 1
    meta = words[address]
    if (meta & m.HALF) == 2 and ((meta >> 18) & 7) == 4:
        if meta_addr is not None:
            raise SystemExit('v1673: duplicate real slot2 MM owner')
        meta_addr = address
if meta_addr is None:
    raise SystemExit('v1673: missing original slot2 RAW MM owner')
original_meta = words[meta_addr]
emit('unsafe-packed-type', meta_addr,
     (original_meta & ~(7 << 18)) | (1 << 18))

proc_table = words[symbol('proc_table')]
process_meta = words[proc_table + 2 * 3]
uarea = (process_meta >> 18) & m.HALF
saved = uarea + 0o406
if not uarea or saved not in words or not words[saved]:
    raise SystemExit('v1673: no real saved immutable backing to mutate')
emit('unsafe-saved-backing', saved, words[saved] ^ 1)

(root / 'unsafe-missing-release.log').write_text(
    source.replace(end, 'V1673 CORRUPT RELEASE B', 1), encoding='ascii')

# Mutate the B native counter without modifying the physical MM.
actual = json.loads(Path(report_path).read_text(encoding='ascii'))[\
    'native_meminfo']['PROCESS-WORDS'][1]
marker = 'V1673 PROCESS-WORDS %d' % actual
if marker not in before + head + between:
    raise SystemExit('v1673: source-linked native resident counter drift')
pressure_start = source.index('V1673 PRESSURE')
counter = source.index(marker, pressure_start)
source_counter = source[:counter] + \
    ('V1673 PROCESS-WORDS %d' % (actual + 1)) + \
    source[counter + len(marker):]
(root / 'unsafe-native-counter.log').write_text(source_counter,
                                                 encoding='ascii')

report = json.loads(Path(report_path).read_text(encoding='ascii'))
report['pressure']['free_words'] += 1
report['samples'][1]['free_words'] += 1
(root / 'unsafe-summary.json').write_text(json.dumps(report),encoding='ascii')
PY

for variant in unsafe-storage-mode unsafe-packed-type \
    unsafe-saved-backing unsafe-missing-release unsafe-native-counter; do
    if python3 "$here/measure-v1673.py" "$fixture" "$coremap" \
        "$work/$variant.log" 48 "$work/$variant-report.json" \
        > "$work/$variant-refusal.log" 2>&1; then
        echo "FAIL v1673: $variant escaped the original physical decoder" >&2
        keep=1; exit 1
    fi
    grep -q '^FAIL v1673 physical RUN/WAIT memory:' \
        "$work/$variant-refusal.log" || {
        cat "$work/$variant-refusal.log" >&2
        keep=1; exit 1
    }
    echo "v1673: original oracle rejected executed $variant"
done
if python3 "$here/compare-v1673.py" "$accepted" \
    "$work/unsafe-summary.json" \
    > "$work/unsafe-summary-refusal.log" 2>&1; then
    echo 'FAIL v1673: forged MM free summary passed comparison' >&2
    keep=1;exit 1
fi
grep -q '^FAIL v1673 paired physical RAW PURE:' \
    "$work/unsafe-summary-refusal.log" || {
    cat "$work/unsafe-summary-refusal.log" >&2
    keep=1;exit 1
}
echo 'PASS v1673: five physical MM/banking/CTY mutants plus forged summary rejected'
