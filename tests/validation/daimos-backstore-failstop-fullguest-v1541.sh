#!/bin/sh
# Real PDP-6 BACKSTORE failure after actual Type-236 PI2 device error.
# Reuse v1511's source-linked, selected-owner physical error injection,
# but require the newer v1541 fatal policy rather than its old rollback.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

output=$(V1511_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-device-error-physical-v1511.sh")
printf '%s\n' "$output" | tail -5
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1511: prepared mapped real DRM read-error guest at //p' | tail -1)
test -n "$work" && test -s "$work/runner-v1511.sh"

# Keep all guest instrumentation from v1511 but use the same accepted
# v1306 SIMH monitor with a tiny linked address set. Hundreds of
# periodic post-break EXAMINE commands exceed some PTY input queues.
# After the real HALT, examine only the exact controller error count,
# selected fault counter, enabled flag and owned block count before EXIT.
python3 - "$work/runner-v1511.sh" "$work/runner-v1541.sh" \
    "$work/sampler-v1511.py" \
    "$self/daimos-backstore-mini-sampler-v1541.py" <<'PY'
from pathlib import Path
import sys

src, dst, old_sampler, new_sampler = [Path(s) for s in sys.argv[1:]]
text = src.read_text()
assert text.count(str(old_sampler)) == 1
text = text.replace(str(old_sampler), str(new_sampler))
inject = ('python3 "$self/daimos-backstore-device-error-observer-v1511.py" \\\n'
          '    "$work/source/system/kernel"\n')
assert text.count(inject) == 1
text = text.replace(inject, inject +
    'python3 "$self/daimos-backstore-first-write-v1541.py" \\\n'
    '    "$work/source/system/kernel"\n', 1)
anchor = 'if [ "${V1306_LIVE_SAMPLER:-0}" = 1 ]; then'
assert text.count(anchor) == 1
add = '''# v1541: short *disposable* post-HALT physical error witness.
python3 - "$build/boot.ini" "$work/addresses" "$build/kcore.map" <<'PYV1541'
from pathlib import Path
import re
import sys

ini, mapping, kmap = [Path(s).read_text() for s in sys.argv[1:]]
addresses = dict(x.split() for x in mapping.splitlines()
                 if len(x.split()) == 2)
symbols = dict(x.split()[:2] for x in kmap.splitlines()
               if len(x.split()) >= 2)
required = {'v1511_device_errors': addresses['v1511_device_errors'],
            'backstore_enabled': symbols['backstore_enabled'],
            'backstore_blocks_used': symbols['backstore_blocks_used']}
lines = ini.splitlines()
assert sum(line.strip().lower() == 'go 020' for line in lines) == 1
start = next(i for i,s in enumerate(lines) if s.strip().lower() == 'go 020')
assert lines[-1].strip().lower() == 'exit'
tail = ["ex " + v for v in required.values()]
output = lines[:start + 1] + tail + ['exit']
Path(sys.argv[1]).write_text('\\n'.join(output) + '\\n')
print('v1541: four exact linked words after physical HALT: ' +
      ','.join(required))
PYV1541
'''
dst.write_text(text.replace(anchor, add + anchor, 1))
PY
sh -n "$work/runner-v1541.sh"
python3 -m py_compile "$self/daimos-backstore-mini-sampler-v1541.py"
if [ "${V1541_PREPARE_ONLY:-0}" = 1 ]; then
    echo "v1541: prepared short physical runner at $work"
    exit 0
fi

# The full guest runs the genuine F07 swapping workload and fires the
# same selected Type-236 PI2 error as v1511. The diagnostic sampler
# may report early termination because v1541 HALTs at the failed
# transfer, before v1511's expected post-error bystander checkpoints.
# The current oracle requires the actual HALT address, not a sampler
# process exit code or a source-level fake failure.
export KEEP_TEST=1 V1304_PREPARE_ONLY=0
export V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1
export V1205_TEST_CONCURRENT=1 V1206_TEST_COMBINED=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
export V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=${V1541_INTERVAL:-8}
export V1306_COUNT=${V1541_COUNT:-35}
export V1306_TIMEOUT=${V1541_TIMEOUT:-720}
unset V1344_DIAG_STOP

echo 'v1541: real 256K PDP-6 with selected Type-236 PI2 BACKSTORE error'
set +e
sh "$work/runner-v1541.sh" > "$work/runner-v1541.log" 2>&1
runner_rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1541.log" | tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh.out" ] || \
    [ ! -s "$guest/build/system/boot/pdp6/kcore.map" ]; then
    echo 'v1541: full guest never produced evidence or map' >&2
    tail -65 "$work/runner-v1541.log" >&2
    exit 1
fi

python3 "$self/daimos-backstore-physical-verify-v1542.py" --self-test \
    "$guest/build/system/boot/pdp6/kcore.map" \
    "$guest/simh.out" "$guest/simh.out.raw-v1306.log" \
    "$guest/source/system/kernel/fs/fs_mres.s" \
    "$guest/source/system/kernel/drivers/drm236_io.s" \
    "$guest/simh.out.raw-v1306.log"

python3 "$self/daimos-backstore-physical-verify-v1542.py" --self-test \
    "$guest/build/system/boot/pdp6/kcore.map" \
    "$guest/simh.out" "$guest/simh.out.raw-v1306.log" \
    "$guest/source/system/kernel/fs/fs_mres.s" \
    "$guest/source/system/kernel/drivers/drm236_io.s" \
    "$guest/simh-sampler.log"

echo "PASS v1541: full-guest physical BACKSTORE fatal; runner_rc=$runner_rc"
echo "v1541: evidence work=$work guest=$guest"
