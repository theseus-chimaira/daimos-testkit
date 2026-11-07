#!/bin/sh
# Replay the unchanged F07 post-HALT validators against captured PTY evidence.
# This diagnoses simulator-monitor formatting; it does not rerun the guest.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${V1311_GUEST_DIR:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-postflight-v1311.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1311 work: $work"; fi' EXIT HUP INT TERM

test -f "$V1311_GUEST_DIR/addresses"
test -f "$V1311_GUEST_DIR/build.log"
test -f "$V1311_GUEST_DIR/simh.out"
test -f "$V1311_GUEST_DIR/user/init.map"
build="$V1311_GUEST_DIR/build/system/boot/pdp6"
test -f "$build/kcore.map"
test -f "$build/boot.ini"
mkdir -p "$work/user"
cp "$V1311_GUEST_DIR/addresses" "$work/addresses"
cp "$V1311_GUEST_DIR/build.log" "$work/build.log"
cp "$V1311_GUEST_DIR/user/init.map" "$work/user/init.map"

python3 - "$self/daimos-oom-requester-live-v1075.sh" \
    "$V1311_GUEST_DIR/simh.out" "$work/simh.out" \
    "$work/replay-postflight-v1311.sh" <<'PY'
from pathlib import Path
import re
import sys

runner, raw, canonical, extracted = (Path(x) for x in sys.argv[1:])
source = raw.read_bytes()
assert b'HALT instruction, PC:' in source, 'v1311: incomplete guest'
assert b'<++++++++++++++++++' in source and b'KWP' in source, \
    'v1311: missing complete 24-process milestone sequence'
assert b'sim> ' in source, 'v1311: no simulator prompt pollution'
assert b'[v1306] sample=' not in source, 'v1311: raw debug in guest text'
source = re.sub(rb'(?m)^sim> ', b'', source)
canonical.write_bytes(source)

script = runner.read_text()
anchor = "text=$(tr -d '\\r\\n' < \"$work/simh.out\")"
assert script.count(anchor) == 1, 'v1311: original F07 verifier moved'
tail = script[script.index(anchor):]
header = '''#!/bin/sh
set -eu
enable=1
negatives=0
bad_run=0
mm_slots=0
mm_fragment=0
run_cause=0
combined=0
pid_reuse=0
endurance=0
disk_full=0
held_provider=1
protected=1
f07_peak=1
f07_high=0
f07_concurrent=1
f07_swapslots=1
f07_combined=0
residency=0
release_media=1
full_slots=0
extra_count=18
'''
extracted.write_text(header + tail)
PY

sh -n "$work/replay-postflight-v1311.sh"
export work self build
export V1283_PRODUCTION_OOM_DEFAULT=1
export V1160_EVIDENCE_DIR="$work/release-media-v1311"
echo 'v1311: verifying original F07 postflight against a derived '
echo 'v1311: prompt-normalized copy (original guest evidence untouched)'
sh "$work/replay-postflight-v1311.sh" > "$work/replay.log" 2>&1 || {
    tail -35 "$work/replay.log" >&2
    exit 1
}
grep -q 'v1160: explicit 256K KCC DSK/D6FS physical-OOM release-media evidence PASS' \
    "$work/replay.log"
echo 'v1311: original provider, protected witness, MM, real-process, '
echo 'v1311: swap/stack and media postflight validators PASS on '
echo 'v1311: prompt-normalized recorded guest; NOT a new guest run'
echo "v1311: replay evidence=$work"
