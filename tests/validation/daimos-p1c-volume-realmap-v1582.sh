#!/bin/sh
# Actual PDP-6 BSET MRES interleave mapper + fixed BACKSTORE critical gate.
# Physical sector completion is test-driven; do not call this a full guest.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-volume-v1582.XXXXXX")
if [ "${V1582_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1582 evidence: $work"
fi

python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import re
import sys

repo, tests, work = [Path(s) for s in sys.argv[1:]]
mapper = (repo / 'system/kernel/storage/blockset_dispatch.s').read_text()
gateway = (repo / 'system/kernel/fs/fs_mres.s').read_text()
fatal = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
first = 'blockset_direct_configure:\n'
last = 'blockset_tail_blocks:\n'
assert gateway.count(first) == gateway.count(last) == 1
bridge = gateway[gateway.index(first):gateway.index(last)]
leaf = 'kcore_critical_device_lost_v1515:\n'
assert fatal.count(leaf) == 1
halt = fatal[fatal.index(leaf):]
assert halt.count('halt    .') == 3
assert 'blockset_map_block:\n' in mapper
assert 'blockset_boot:         .block 012' in mapper
assert 'jrst    kcore_critical_device_lost_v1515' in bridge

linked = ('.text\n'
          '.globl volume_tail_configure\n'
          '.globl blockset_runtime_service_call\n'
          '.globl backstore_read\n'
          '.globl backstore_write\n'
          '.globl kcore_critical_media_swap_halt_v1515\n'
          '.globl kcore_critical_media_root_halt_v1515\n'
          + bridge + halt + '\n' + mapper)
(work / 'linked-source-v1582.s').write_text(linked)

mutants = (
    ('wrong-physical-block', 'add 2,3', 'addi 2,1',
     'dsk-three-read'),
    ('wrong-member-unit', 'move 1,blockset_boot+2(1)',
     'movei 1,0', 'drm-six-write'),
    ('skip-data-offset', 'add     1,volume_data_blocks',
     'add     1,backing_region_count', 'dsk-three-read'),
    ('misroute-drum', 'trne    0,0400000', 'trnn    0,0400000',
     'drm-three-read'),
    ('lose-fatal', 'jrst    kcore_critical_device_lost_v1515',
     'popj    17,', 'drm-middle-fatal'),
    ('bypass-mapper-failure', 'jumpl   1,blockset_direct_tail_done',
     'jrst    device_block_transfer', 'mapper-missing-fatal'),
    ('lose-disabled-owner', 'skipn   backstore_blocks_used',
     'skipn   test_dummy_zero_v1582', 'disabled-owned-fatal'),
    ('wrong-buffer-stride', 'addi    010,0200',
     'addi    010,0100', 'dsk-three-read'),
)
for name, before, after, case in mutants:
    assert linked.count(before) == 1, ('nonunique source mutation', name)
    source = linked.replace(before, after, 1)
    if name == 'lose-disabled-owner':
        source = '.globl test_dummy_zero_v1582\n' + source
    (work / ('mutant-' + name + '-v1582.s')).write_text(source)
    (work / ('mutant-case-' + name)).write_text(case)

fixture = (tests / 'daimos-p1c-volume-realmap-v1582.s').read_text()
settings = {
    'test_install_mapper_v1582': '1',
    'test_tag_v1582': '0',
    'test_write_v1582': '0',
    'test_first_v1582': '0',
    'test_count_v1582': '3',
    'test_result_v1582': '0',
    'test_calls_v1582': '3',
    'test_fail_at_v1582': '0',
    'test_writes_v1582': '0',
    'test_drums_v1582': '0',
    'test_owner_v1582': '0300',
    'backstore_enabled': '1',
    'backstore_blocks_used': '0300',
}
cases = (
    ('dsk-three-read', {}, False),
    ('dsk-six-write', {'test_write_v1582': '1',
                       'test_count_v1582': '6',
                       'test_calls_v1582': '6',
                       'test_writes_v1582': '6'}, False),
    ('drm-three-read', {'test_tag_v1582': '0400000',
                        'test_drums_v1582': '3'}, False),
    ('drm-six-write', {'test_tag_v1582': '0400000',
                       'test_write_v1582': '1',
                       'test_count_v1582': '6',
                       'test_calls_v1582': '6',
                       'test_drums_v1582': '6',
                       'test_writes_v1582': '6'}, False),
    ('dsk-middle-fatal', {'test_fail_at_v1582': '2',
                          'test_calls_v1582': '2'}, True),
    ('drm-middle-fatal', {'test_tag_v1582': '0400000',
                          'test_write_v1582': '1',
                          'test_fail_at_v1582': '3',
                          'test_calls_v1582': '3',
                          'test_drums_v1582': '3',
                          'test_writes_v1582': '3'}, True),
    ('disabled-owned-fatal', {'backstore_enabled': '0',
                              'test_fail_at_v1582': '1',
                              'test_calls_v1582': '1'}, True),
    ('disabled-unowned-refusal', {'backstore_enabled': '0',
                                  'backstore_blocks_used': '0',
                                  'test_owner_v1582': '0',
                                  'test_fail_at_v1582': '1',
                                  'test_calls_v1582': '1',
                                  'test_result_v1582': '-1'}, False),
    ('mapper-missing-fatal', {'test_install_mapper_v1582': '0',
                              'test_calls_v1582': '0'}, True),
    ('mapper-missing-inactive', {'test_install_mapper_v1582': '0',
                                'test_calls_v1582': '0',
                                'backstore_enabled': '0',
                                'backstore_blocks_used': '0',
                                'test_owner_v1582': '0',
                                'test_result_v1582': '-1'}, False),
    ('range-overflow', {'test_first_v1582': '0277',
                        'test_count_v1582': '2',
                        'test_calls_v1582': '0',
                        'test_result_v1582': '-1'}, False),
    ('range-at-end', {'test_first_v1582': '0300',
                      'test_count_v1582': '1',
                      'test_calls_v1582': '0',
                      'test_result_v1582': '-1'}, False),
    ('zero-blocks', {'test_count_v1582': '0',
                     'test_calls_v1582': '0'}, False),
)
for name, override, fatal_case in cases:
    values = dict(settings)
    values.update(override)
    lines = fixture.splitlines(keepends=True)
    for field, value in values.items():
        matches = [i for i, line in enumerate(lines)
                   if re.match(r'^' + re.escape(field) +
                               r':\s+\.word\s+', line)]
        assert len(matches) == 1, (name, field, matches)
        lines[matches[0]] = field + ': .word ' + value + '\n'
    # An executed source mutation that ignores owned BACKSTORE uses a
    # test zero word, never a fake owner-in-production replacement.
    lines.append('\n.data\n.globl test_dummy_zero_v1582\n'
                 'test_dummy_zero_v1582: .word 0\n')
    (work / ('case-' + name + '-v1582.s')).write_text(''.join(lines))
    (work / ('check-' + name + '-v1582.txt')).write_text(
        '%d\n%s\n%s\n%s\n%s\n' %
        (int(fatal_case), values['test_calls_v1582'],
         values['test_writes_v1582'], values['test_drums_v1582'],
         values['test_owner_v1582']))
print('v1582: %d native real-mapper scenarios and %d unsafe mutants' %
      (len(cases), len(mutants)))
PY

run_one() {
    label=$1
    scenario=$2
    source=$3
    check="$work/check-$scenario-v1582.txt"
    fatal=$(sed -n '1p' "$check")
    calls=$(sed -n '2p' "$check")
    writes=$(sed -n '3p' "$check")
    drums=$(sed -n '4p' "$check")
    owner=$(sed -n '5p' "$check")
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 225000 --timeout 20 \
        --workdir "$work/run-$label" --name "volume-$label-v1582" \
        --expect "__test_exit=$fatal" \
        --expect "observed_wrong_v1582=0" \
        --expect "observed_io_v1582=$calls" \
        --expect "observed_writes_v1582=$writes" \
        --expect "observed_drums_v1582=$drums" \
        --expect "backstore_blocks_used=$owner" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$scenario-v1582.s" "$source" \
        > "$work/$label.log" 2>&1
}

verify_halt() {
    label=$1
    python3 - "$work/run-$label/volume-$label-v1582.report.txt" \
        "$work/run-$label/volume-$label-v1582.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(x).read_text() for x in sys.argv[1:])
pc = re.findall(r'HALT instruction, PC: ([0-7]{6})', report)
syms = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
expected = syms['kcore_critical_media_swap_halt_v1515']
root = syms['kcore_critical_media_root_halt_v1515']
assert pc == [expected] and pc != [root], (pc, expected, root)
PY
}

for scenario in dsk-three-read dsk-six-write drm-three-read \
    drm-six-write dsk-middle-fatal drm-middle-fatal \
    disabled-owned-fatal disabled-unowned-refusal \
    mapper-missing-fatal mapper-missing-inactive \
    range-overflow range-at-end zero-blocks; do
    if ! run_one "$scenario" "$scenario" "$work/linked-source-v1582.s"; then
        tail -55 "$work/$scenario.log" >&2
        exit 1
    fi
    if [ "$(sed -n '1p' "$work/check-$scenario-v1582.txt")" = 1 ]; then
        verify_halt "$scenario"
    fi
    echo "PASS v1582: real BLOCKSET mapped $scenario"
done

for mutant in wrong-physical-block wrong-member-unit skip-data-offset \
    misroute-drum lose-fatal bypass-mapper-failure lose-disabled-owner \
    wrong-buffer-stride; do
    scenario=$(cat "$work/mutant-case-$mutant")
    label="mutant-$mutant"
    source="$work/$label-v1582.s"
    if run_one "$label" "$scenario" "$source"; then
        if [ "$(sed -n '1p' "$work/check-$scenario-v1582.txt")" = 0 ]; then
            echo "FAIL v1582: accepted mutant $mutant" >&2
            exit 1
        fi
        if verify_halt "$label"; then
            echo "FAIL v1582: accepted mutant $mutant" >&2
            exit 1
        fi
    fi
    echo "PASS v1582: rejected executed mutant $mutant"
done
echo 'PASS v1582: source-linked actual PDP-6 BLOCKSET mapper and BACKSTORE critical isolation'
echo 'P1-C remains open: full physical multi-member VOLUME and overlapping PI still unproven'
