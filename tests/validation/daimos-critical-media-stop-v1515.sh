#!/bin/sh
# Source-linked native PDP-6 terminal stop. Not a proof of media detection.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-critical-media-stop-v1515.XXXXXX")
if [ "${V1515_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
python3 - "$DAIMOS_REPO" "$work" "$self" <<'PY'
from pathlib import Path
import sys

repo, work, tests = (Path(x) for x in sys.argv[1:])
source = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
start = 'kcore_critical_device_lost_v1515:\n'
assert source.count(start) == 1, 'v1515 missing critical media source'
tail = source[source.index(start):]
assert tail.count('cono    0004,000400') == 1, 'must inhibit global PI'
assert tail.count('halt    .') == 3, 'must use safe self-halting PC'
assert not any(x in tail for x in ('halt    4', 'halt    5', 'halt    6'))
assert tail.count('jrst    .-1') == 3, 'continue-after-HALT guard'
assert not any(x in tail for x in ('popj', 'proc_exit_current',
                                   'backstore_free', 'vfs_unmount'))
head = ('.text\n.globl kcore_critical_device_lost_v1515\n'
        '.globl kcore_critical_media_root_halt_v1515\n'
        '.globl kcore_critical_media_swap_halt_v1515\n'
        '.globl kcore_critical_media_bad_reason_v1515\n')
(work / 'media-stop-v1515.s').write_text(head + tail)
for label, old, new in (
        ('no-root-halt',
         'kcore_critical_media_root_halt_v1515:\n        halt    .',
         'kcore_critical_media_root_halt_v1515:\n        popj    17,'),
        ('no-swap-halt',
         'kcore_critical_media_swap_halt_v1515:\n        halt    .',
         'kcore_critical_media_swap_halt_v1515:\n        popj    17,'),
        ('no-unknown-halt',
         'kcore_critical_media_bad_reason_v1515:\n        halt    .',
         'kcore_critical_media_bad_reason_v1515:\n        popj    17,')):
    assert tail.count(old) == 1, 'missing unique mutation anchor: ' + label
    (work / ('mutant-' + label + '-v1515.s')).write_text(
        head + tail.replace(old, new, 1))

fixture = tests / 'daimos-critical-media-stop-v1515.s'
if not fixture.exists():
    raise AssertionError('v1515 reason fixture unavailable')
f = fixture.read_text()
assert f.count('        .word 1\n') == 1
for reason in (1, 2, 0):
    (work / ('reason-%d-v1515.s' % reason)).write_text(
        f.replace('        .word 1\n', '        .word %d\n' % reason))
print('v1515: strict source and three reason fixtures PASS')
PY

run_native() {
    label=$1
    reason=$2
    leaf=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 10000 --timeout 15 \
        --workdir "$work/run-$label" --name "critical-$label-v1515" \
        --expect __test_exit=1 \
        "$self/daimos-test-crt0-v1.s" \
        "$work/reason-$reason-v1515.s" \
        "$leaf" > "$work/$label.log" 2>&1
}

for spec in root:1 swap:2 invalid:0; do
    label=${spec%%:*}
    reason=${spec#*:}
    run_native "$label" "$reason" "$work/media-stop-v1515.s" || {
        echo "FAIL v1515 $label: no verified terminal stop" >&2
        tail -40 "$work/$label.log" >&2
        exit 1
    }
    case "$label" in
        root) symbol=kcore_critical_media_root_halt_v1515 ;;
        swap) symbol=kcore_critical_media_swap_halt_v1515 ;;
        invalid) symbol=kcore_critical_media_bad_reason_v1515 ;;
    esac
    python3 - "$work/run-$label/critical-$label-v1515.report.txt" \
        "$work/run-$label/critical-$label-v1515.labels" "$symbol" <<'PY'
from pathlib import Path
import re
import sys

report, labels = (Path(x).read_text() for x in sys.argv[1:3])
symbol = sys.argv[3]
halt = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert halt is not None, 'no genuine simulator HALT'
found = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
assert symbol in found, 'no linked reason-specific HALT symbol: ' + symbol
assert halt.group(1) == found[symbol], (
    'wrong HALT PC for ' + symbol + ': ' + halt.group(1) +
    ' != ' + found[symbol])
assert int(halt.group(1), 8) >= 0o1000, 'HALT escaped into low core'
print('v1515: exact link-symbol HALT PC = ' + halt.group(1))
PY
    echo "PASS v1515: $label critical-media no-return HALT"
done

for spec in no-root-halt:1 no-swap-halt:2 no-unknown-halt:0; do
    label=${spec%%:*}
    reason=${spec#*:}
    if run_native "$label" "$reason" "$work/mutant-$label-v1515.s"; then
        echo "FAIL v1515: accepted missing $label" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$label.log" || {
        echo "FAIL v1515: mutation $label did not reach native oracle" >&2
        tail -30 "$work/$label.log" >&2
        exit 1
    }
    echo "PASS v1515: rejected $label mutation"
done
