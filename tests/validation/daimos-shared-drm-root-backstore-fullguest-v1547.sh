#!/bin/sh
# Real PDP-6: ROOT=drum and BACKSTORE on the same selected Type-236 set.
# Reuse original selected-descriptor PI2 error injection; only test guest
# boot profile and post-HALT read-only examination change.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

output=$(V1541_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-failstop-fullguest-v1541.sh")
printf '%s\n' "$output" | tail -5
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1541: prepared short physical runner at //p' | tail -1)
test -n "$work" && test -s "$work/runner-v1541.sh"

python3 - "$work/runner-v1541.sh" "$work/runner-v1547.sh" <<'PY'
from pathlib import Path
import sys

source, destination = (Path(x) for x in sys.argv[1:])
script = source.read_text()
changes = (
    ('set -- BOOT=dsk ROOT=disk ROOTSET=1 COMPILER=kcc',
     'set -- BOOT=drm ROOT=drum ROOTSET=1 COMPILER=kcc'),
    ("printf 'boot=dsk\\nroot=disk\\nrootset=1\\n'",
     "printf 'boot=drm\\nroot=drum\\nrootset=1\\n'"),
    ("'backstore_blocks_used': symbols['backstore_blocks_used']}",
     "'backstore_blocks_used': symbols['backstore_blocks_used'],\n"
     "            'device_region_map': symbols['device_region_map'],\n"
     "            'volume_data_blocks': symbols['volume_data_blocks'],\n"
     "            'vfs_namespace_root': symbols['vfs_namespace_root']}"),
)
for before, after in changes:
    assert script.count(before) == 1, (before, script.count(before))
    script = script.replace(before, after, 1)
destination.write_text(script)
print('v1547: disposable full 256K ROOT=drum shared BACKSTORE runner prepared')
PY
sh -n "$work/runner-v1547.sh"

if [ "${V1547_PREPARE_ONLY:-0}" = 1 ]; then
    echo "v1547: prepared shared physical guest at $work"
    exit 0
fi

export KEEP_TEST=1 V1304_PREPARE_ONLY=0
export V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1
export V1205_TEST_CONCURRENT=1 V1206_TEST_COMBINED=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
export V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=${V1547_INTERVAL:-8}
export V1306_COUNT=${V1547_COUNT:-35}
export V1306_TIMEOUT=${V1547_TIMEOUT:-720}
unset V1344_DIAG_STOP

echo 'v1547: booting shared root+swap on Type-236 DR0..DR3'
set +e
sh "$work/runner-v1547.sh" > "$work/runner-v1547.log" 2>&1
runner_rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1547.log" | tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh.out.raw-v1306.log" ]; then
    tail -65 "$work/runner-v1547.log" >&2
    echo 'v1547: full guest failed to produce physical evidence' >&2
    exit 1
fi

python3 "$self/daimos-backstore-physical-verify-v1542.py" --self-test \
    "$guest/build/system/boot/pdp6/kcore.map" \
    "$guest/simh.out" "$guest/simh.out.raw-v1306.log" \
    "$guest/source/system/kernel/fs/fs_mres.s" \
    "$guest/source/system/kernel/drivers/drm236_io.s" \
    "$guest/simh.out.raw-v1306.log"

python3 - "$guest/build/system/boot/pdp6/kcore.map" \
    "$guest/build/system/boot/pdp6/boot.ini" \
    "$guest/simh.out.raw-v1306.log" <<'PY'
from pathlib import Path
import re
import sys

mapping, boot, raw = (Path(s).read_text(errors='replace')
                      for s in sys.argv[1:])
assert re.search(r'(?m)^deposit SW 3\s*$', boot)
assert re.search(r'(?m)^attach -q dr0 \S+/drum/dsk0.dsk\s*$', boot)
symbols = {}
for line in mapping.splitlines():
    cols = line.split()
    if len(cols) >= 2 and re.fullmatch('[0-7]{6}', cols[1]):
        symbols[cols[0]] = int(cols[1],8)
post = raw.split('HALT instruction, PC:',1)[1]
values = {}
for name in ('device_region_map', 'volume_data_blocks',
             'vfs_namespace_root', 'backstore_blocks_used'):
    addr = symbols[name]
    match = re.findall(r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % addr, post)
    assert len(match)==1, (name,match)
    values[name] = int(match[0],8)
selector = values['device_region_map'] >> 18
assert selector & 0o400000, 'BACKSTORE did not select DRM236'
assert values['volume_data_blocks'] > 0, 'no four-member root VOLUME'
assert (values['vfs_namespace_root'] >> 24) == 0o601, 'root not D6FS mount 1'
assert values['backstore_blocks_used'] > 0, 'lost swap ownership'
print('PASS v1547: shared DRM ROOT and mapped BACKSTORE')
print('v1547: selector=%06o volume_data=%06o owned=%06o' %
      (selector, values['volume_data_blocks'],values['backstore_blocks_used']))
PY
echo "PASS v1547: shared full-guest Type-236 BACKSTORE HALT; runner_rc=$runner_rc"
echo "v1547: evidence work=$work guest=$guest"
