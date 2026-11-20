#!/bin/sh
# Production MM transfer/shrink/grow, with injected PI mutations at stores.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-pinned-mutate-pi-v1699.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 - "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" "$self" "$work" <<'PY'
from pathlib import Path
import sys

mm = Path(sys.argv[1]).read_text()
self = Path(sys.argv[2])
work = Path(sys.argv[3])
cases = (
    ('transfer', 'mm_process_transfer_pinned:',
     '; int mm_process_shrink_pinned', 'daimos-mm-owner-transfer-native-v767.s'),
    ('shrink', 'mm_process_shrink_pinned:',
     '; int mm_process_grow_pinned', 'daimos-mm-shrink-native-v768.s'),
    ('grow', 'mm_process_grow_pinned:',
     '; AC1=base, AC2=+1/-1', 'daimos-mm-grow-native-v769.s'),
)
for kind, start, end, fixture_name in cases:
    assert mm.count(start) == 1
    fragment = start + mm.split(start, 1)[1].split(end, 1)[0]
    assert '        cono    0004,000400\n' in fragment
    if kind == 'transfer':
        anchor = '        movem   4,mm_extents+1(1)\n'
        mutation = '''        coni    0004,0
        trnn    0,000200
        jrst    mutation_safe_v1699
        move    0,[021,,01]          ; unexpected extra pin
        movem   0,mm_extents+1(1)
        aos     triggered_v1699
mutation_safe_v1699:
'''
    elif kind == 'shrink':
        anchor = '        hrlm    6,mm_extents(1)\n'
        mutation = '''        coni    0004,0
        trnn    0,000200
        jrst    mutation_safe_v1699
        move    0,[021,,01]          ; unexpected extra pin
        movem   0,mm_extents+1(1)
        aos     triggered_v1699
mutation_safe_v1699:
'''
    else:
        anchor = '        hrlm    6,mm_extents(1)\n'
        mutation = '''        coni    0004,0
        trnn    0,000200
        jrst    mutation_safe_v1699
        move    0,[02000,,06000]    ; successor enters growth gap
        movem   0,mm_extents+2
        aos     triggered_v1699
mutation_safe_v1699:
'''
    assert fragment.count(anchor) == 1
    fragment = fragment.replace(anchor, mutation + anchor, 1)
    header = ('.text\n.globl ' + start[:-1] + '\n'
              '.equ MM_TYPE_PROCESS,1\n'
              '.equ MM_PIN_FIELD,03770000000\n'
              '.equ MM_PIN_ONE,010000000\n')
    (work / (kind + '-production.s')).write_text(header + fragment)
    unsafe = fragment.replace('        cono    0004,000400\n',
                              '        move    0,0  ; PI remains enabled\n', 1)
    (work / (kind + '-unsafe.s')).write_text(header + unsafe)

    fixture = (self / fixture_name).read_text()
    assert fixture.count('main:\n') == 1
    fixture = fixture.replace('main:\n',
                              'main:\n        cono 0004,000200\n', 1)
    # Old source-linked tests validate owner or length but not the
    # other descriptor field an interrupt might have mutated.
    if kind == 'shrink':
        anchor = '        jumpn 1,fail\n        hlrz 1,mm_extents\n'
        assert fixture.count(anchor) == 1
        fixture = fixture.replace(anchor, '''        jumpn 1,fail
        move 1,mm_extents+1
        came 1,[011,,01]
        jrst fail
        hlrz 1,mm_extents
''', 1)
    elif kind == 'grow':
        anchor = '        jumpn 1,fail\n        hlrz 1,mm_extents\n'
        assert fixture.count(anchor) == 1
        fixture = fixture.replace(anchor, '''        jumpn 1,fail
        move 1,mm_extents+2
        came 1,[02000,,012000]
        jrst fail
        hlrz 1,mm_extents
''', 1)
    witness = '        jumpn 1,fail\n'
    assert fixture.count(witness) >= 1
    fixture = fixture.replace(witness, '''        jumpn 1,fail
        skipn triggered_v1699
        jrst no_interrupt_v1699
        jrst fail
no_interrupt_v1699:
''', 1)
    fixture += '''\n.bss
.globl triggered_v1699
triggered_v1699: .block 1
'''
    (work / (kind + '-fixture.s')).write_text(fixture)
PY
run()
{
    kind=$1
    variant=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$kind-$variant" \
        --name "k01-pinned-mutate-v1699-$kind-$variant" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/$kind-fixture.s" "$work/$kind-$variant.s" \
        > "$work/$kind-$variant.log" 2>&1
}
for kind in transfer shrink grow; do
    run "$kind" production || {
        tail -45 "$work/$kind-production.log" >&2
        exit 1
    }
    if run "$kind" unsafe; then
        echo "K01 v1699: unsafe PI $kind unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/$kind-unsafe.log" || {
        tail -45 "$work/$kind-unsafe.log" >&2
        exit 1
    }
    echo "K01 v1699: native PDP-6 PI $kind and unsafe mutant PASS"
done
