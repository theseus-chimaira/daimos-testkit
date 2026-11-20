#!/bin/sh
# Verify v997/v1106/v1153 disposable recovery hooks on current MM source.
# This is a source-injection gate, not a physical-guest acceptance test.
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-recovery-injection-v1704.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    echo "K01 v1704 injection work: $work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 - "$self/daimos-oom-pre-vm-retry-v997.sh" \
    "$DAIMOS_REPO/system/kernel" "$work" <<'PY'
from pathlib import Path
import shutil
import subprocess
import sys

script_file = Path(sys.argv[1])
kernel_dir = Path(sys.argv[2])
work = Path(sys.argv[3])
wrapper = script_file.read_text()
start = ('python3 - "$work/source/system/kernel" "$integrated" '
         '"$physical_vm" "$mixed_dpy" <<\'PY\'\n')
assert wrapper.count(start) == 1, 'v997 injection extraction changed'
injection = wrapper.split(start, 1)[1].split('\nPY\n', 1)[0]
assert injection.count('jrst    mm_free_restore_pi_v1697') >= 2
source = work / 'inject-v1704.py'
source.write_text(injection)

cases = (
    ('base', ('0', '0', '0')),
    ('vm', ('0', '1', '0')),
    ('integrated', ('1', '1', '0')),
    ('mixed', ('1', '1', '1')),
)

for name, flags in cases:
    target = work / name / 'kernel'
    shutil.copytree(kernel_dir, target)
    result = subprocess.run(
        [sys.executable, str(source), str(target), *flags],
        capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('v1704: ' + name + ' hooks refused: ' +
                         (result.stdout + result.stderr)[-1200:])
    mm = (target / 'mm/mm_pdp6.s').read_text()
    assert mm.count('mm_free_restore_pi_v1697:') == 1
    assert '        jrst    mm_free_restore_pi_v1697\nmm_free_inval:' in mm
    if flags[1] == '1':
        assert 'daimos_test_vm_mm_frees_v1106' in mm
    if flags[2] == '1':
        assert 'daimos_dpy_frees_v1144' in mm
    print('v1704: current-source injection', name, 'PASS')

# Negative source-hook control: a v997 hook that expects the obsolete
# post-mm_delete POPJ must fail before any full-system image is built.
old = '        jrst    mm_free_restore_pi_v1697\nmm_free_inval:'
assert injection.count(old) >= 2
bad_script = work / 'unsafe-stale-tail-v1704.py'
bad_script.write_text(injection.replace(
    old, '        popj    17,\nmm_free_inval:', 1))
bad_target = work / 'unsafe' / 'kernel'
shutil.copytree(kernel_dir, bad_target)
result = subprocess.run(
    [sys.executable, str(bad_script), str(bad_target), '0', '1', '0'],
    capture_output=True, text=True)
if result.returncode == 0:
    raise SystemExit('v1704: obsolete MM-free tail hook was accepted')
if 'nonunique kernel injection anchor mm/mm_pdp6.s' not in (
        result.stdout + result.stderr):
    raise SystemExit('v1704: unsafe failure not due to stale MM hook')
print('v1704: obsolete MM-free tail unsafe mutant rejected PASS')
PY
