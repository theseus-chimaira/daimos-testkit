#!/bin/sh
# Full PDP-6: real ROOT data fault first while mapped BACKSTORE is owned.
# Source injectors and user probe run only in disposable guest workdirs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

output=$(V1547_PREPARE_ONLY=1 sh \
    "$self/daimos-shared-drm-root-backstore-fullguest-v1547.sh")
printf '%s\n' "$output" | tail -5
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1547: prepared shared physical guest at //p' | tail -1)
test -n "$work" && test -s "$work/runner-v1547.sh"

python3 - "$work/runner-v1547.sh" "$work/runner-v1548.sh" <<'PY'
from pathlib import Path
import sys

source, destination = (Path(s) for s in sys.argv[1:])
script = source.read_text()
changes = (
    ('python3 "$self/daimos-backstore-first-write-v1541.py" \\\n'
     '    "$work/source/system/kernel"\n',
     'python3 "$self/daimos-shared-root-first-arm-v1548.py" \\\n'
     '    "$work/source/system/kernel"\n'),
    ('requester_source="$v1304_user_source"\n',
     'python3 "$self/daimos-shared-root-first-probe-v1548.py" \\\n'
     '    "$v1304_user_source"\n'
     'requester_source="$v1304_user_source"\n'),
    ("'vfs_namespace_root': symbols['vfs_namespace_root']}",
     "'vfs_namespace_root': symbols['vfs_namespace_root'],\n"
     "            'daimos_v1548_root_arm_count': "
     "symbols['daimos_v1548_root_arm_count'],\n"
     "            'daimos_v1548_owner_at_arm': "
     "symbols['daimos_v1548_owner_at_arm']}"),
)
for before, after in changes:
    assert script.count(before) == 1, (before, script.count(before))
    script = script.replace(before, after, 1)
destination.write_text(script)
print('v1548: prepared real root-data read and selected PI2 root error')
PY
sh -n "$work/runner-v1548.sh"

if [ "${V1548_PREPARE_ONLY:-0}" = 1 ]; then
    echo "v1548: prepared physical ROOT-first guest at $work"
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
export V1306_INTERVAL=${V1548_INTERVAL:-8}
export V1306_COUNT=${V1548_COUNT:-35}
export V1306_TIMEOUT=${V1548_TIMEOUT:-720}
unset V1344_DIAG_STOP

echo 'v1548: full 256K PDP-6 shared DR0..DR3 root-first fault'
set +e
sh "$work/runner-v1548.sh" > "$work/runner-v1548.log" 2>&1
runner_rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1548.log" | tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh.out.raw-v1306.log" ] || \
    [ ! -s "$guest/build/system/boot/pdp6/kcore.map" ]; then
    echo 'v1548: missing actual full-guest root-fault evidence' >&2
    tail -65 "$work/runner-v1548.log" >&2
    exit 1
fi

python3 "$self/daimos-shared-drm-root-first-verify-v1548.py" --self-test \
    "$guest/build/system/boot/pdp6/kcore.map" \
    "$guest/build/system/boot/pdp6/boot.ini" \
    "$guest/simh.out" "$guest/simh.out.raw-v1306.log" \
    "$guest/source/system/kernel/fs/d6fs_runtime.s" \
    "$guest/source/system/kernel/drivers/drm236_io.s"

echo "PASS v1548: root-first full physical HALT; runner_rc=$runner_rc"
echo "v1548: evidence work=$work guest=$guest"
