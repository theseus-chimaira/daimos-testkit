#!/bin/sh
# Native PDP-6 test of the original drum completion/promotion code.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-drm236-pi-v1247.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/drivers/drm236_io.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
anchor = 'drm236_finish_active_v1079:\n'
if source.count(anchor) != 1:
    raise ValueError('v1247: completion helper moved')
source = source.replace(anchor,
    '        .globl drm236_finish_active_v1079\n' + anchor, 1)
(work / 'normal.s').write_text(source)
for reg in (3, 4, 5, 6):
    before = '        push    017,%d\n' % reg
    after = '        pop     017,%d\n' % reg
    if source.count(before) != 1 or source.count(after) != 1:
        raise ValueError('v1247: missing unique saved AC%d' % reg)
    # Drop only one matching PUSH/POP pair, retaining valid source and stack
    # balance. The positive control must observe the damaged exact AC.
    mutant = source.replace(before, '', 1).replace(after, '', 1)
    (work / ('mutant%d.s' % reg)).write_text(mutant)
PY

run_case()
{
    name=$1
    expect=$2
    src=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 20000 --timeout 20 \
        --workdir "$work/$name" --name "$name" \
        --expect "__test_exit=$expect" \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-drm236-pi-registers-v1247.s" \
        "$src" \
        "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
        "$DAIMOS_REPO/system/kernel/core/ret.s" \
        > "$work/$name.log" 2>&1 || {
            tail -35 "$work/$name.log" >&2
            exit 1
        }
}

run_case drm236-pi-v1247 0 "$work/normal.s"
run_case drm236-pi-mutant3-v1247 1 "$work/mutant3.s"
run_case drm236-pi-mutant4-v1247 2 "$work/mutant4.s"
run_case drm236-pi-mutant5-v1247 3 "$work/mutant5.s"
run_case drm236-pi-mutant6-v1247 4 "$work/mutant6.s"
echo 'v1247: DRM completion/promotion PI AC3..AC6 and four negative mutants PASS'
