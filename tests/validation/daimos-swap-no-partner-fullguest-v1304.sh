#!/bin/sh
# Increase actual user image pressure in an isolated F07 256K PDP-6 guest.
# Keep the production VM, MM, swap, scheduler and provider paths untouched.
# The outcome is INCONCLUSIVE unless the real MM no-partner branch runs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-no-partner-v1304.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1304 fixture: $work"; fi' EXIT HUP INT TERM

python3 - "$self/daimos-oom-requester-live-v1075.sh" \
    "$self/daimos-oom-requester-live-v1075.c" \
    "$self/../test_sixbit.h" "$self" "$work" <<'PY'
from pathlib import Path
import sys

runner, csrc, include, source_dir, work = (Path(p) for p in sys.argv[1:])
text = runner.read_text()
old = 'self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)'
assert text.count(old) == 1
text = text.replace(old, 'self="%s"' % source_dir, 1)
old = 'requester_source="$self/daimos-oom-requester-live-v1075.c"'
assert text.count(old) == 1
text = text.replace(old, 'requester_source="$v1304_user_source"', 1)
marker = 'requester_source="$v1304_user_source"'
text = text.replace(marker, 'v1304_user_source="%s"\n%s' %
                    (work / 'pressure-init-v1304.c', marker), 1)
# The 24K-word per-process test causes substantially more real drum I/O
# than the ordinary 16K-word fixture. Keep the same strict assertions,
# but give this distinct guest a bounded 30-minute execution budget.
old = 'if [ "$f07_swapslots" = 1 ]; then guest_timeout=900s; fi'
assert text.count(old) == 1, 'v1304 guest-timeout anchor changed'
text = text.replace(old,
                    'if [ "$f07_swapslots" = 1 ]; then guest_timeout=1800s; fi',
                    1)
# Opt-in live console sampling uses a PTY to interrupt the emulator for
# a read-only snapshot, then resumes it.  Keep the default mode exactly
# unchanged for ordinary F07/physical release acceptance.
old = '''(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \\
    SDL_AUDIODRIVER=dummy timeout -k 2s "$guest_timeout" stdbuf -o0 -e0 \\
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?'''
assert text.count(old) == 1, 'v1306: simulator launch site changed'
new = '''if [ "${V1306_LIVE_SAMPLER:-0}" = 1 ]; then
    (cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \\
        SDL_AUDIODRIVER=dummy python3 \\
        "$self/daimos-simh-swap-live-sampler-v1306.py" \\
        --simh "$PDP10_PREFIX/bin/pdp6" \\
        --ini "$build/boot.ini" --addresses "$work/addresses" \\
        --log "$work/simh.out" \\
        --interval "${V1306_INTERVAL:-60}" \\
        --count "${V1306_COUNT:-3}" \\
        --timeout "${V1306_TIMEOUT:-1810}") \\
        > "$work/simh-sampler.log" 2>&1
    rc=$?
else
    ''' + old + '''
fi'''
text = text.replace(old, new, 1)
(work / 'runner-v1304.sh').write_text(text)

source = csrc.read_text()
rules = (
    ('#include "../test_sixbit.h"', '#include "%s"' % include),
    ('#define V1075_PRESSURE_WORDS 040000',
     '#define V1075_PRESSURE_WORDS 060000'),
    ('#define V1075_PRESSURE_LAST 037777',
     '#define V1075_PRESSURE_LAST 057777'),
)
for old, new in rules:
    assert source.count(old) == 1, 'v1304 source anchor changed: ' + old
    source = source.replace(old, new, 1)
(work / 'pressure-init-v1304.c').write_text(source)
PY
if [ "${V1304_PREPARE_ONLY:-0}" = 1 ]; then
    sh -n "$work/runner-v1304.sh"
    echo "v1304: verified disposable runner: $work/runner-v1304.sh"
    exit 0
fi

export V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1205_TEST_CONCURRENT=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
export KEEP_TEST=1
echo 'v1304: boot genuine 256K KCC F07 with 24K-word per-process BSS'
set +e
sh "$work/runner-v1304.sh" > "$work/runner.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1304: full guest FAILED ($rc), not a no-partner acceptance" >&2
    tail -55 "$work/runner.log" >&2
    exit "$rc"
fi
guest=$(sed -n 's/^v1075 work: //p' "$work/runner.log" | tail -1)
test -n "$guest" && test -f "$guest/addresses"
python3 "$self/daimos-swap-no-partner-physical-v1303.py" --self-test
set +e
python3 "$self/daimos-swap-no-partner-physical-v1303.py" \
    "$guest/addresses" "$guest/simh.out"
classified=$?
set -e
if [ "$classified" = 3 ]; then
    echo 'v1304: full guest PASS; no-partner branch unexercised (not accepted)'
elif [ "$classified" = 0 ]; then
    echo 'v1304: full guest and genuine no-partner pressure PASS'
else
    echo "v1304: evidence verification FAILED ($classified)" >&2
    exit "$classified"
fi
echo "v1304: evidence work=$work guest=$guest"
