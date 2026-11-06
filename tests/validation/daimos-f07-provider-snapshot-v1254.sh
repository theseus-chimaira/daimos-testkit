#!/bin/sh
# Diagnostic-only PDP-6 provider/DRM state and read-only SIMH checkpoint.
# The wrapper never patches the kernel source; use fresh guest media. SIMH
# may write mounted device images during a run.
# Do not resume a checkpoint taken during active disk I/O: the saved CPU/RAM
# state does not guarantee that an in-flight hardware completion is resumed.
set -eu
: "${F07_GUEST_BUILD:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
build=$F07_GUEST_BUILD
test -r "$build/boot.ini" && test -r "$build/kcore.map" || {
    echo 'v1254: boot.ini and matching kcore.map required' >&2
    exit 2
}
out=${F07_SNAPSHOT_DIR:-$TMPDIR/daimos-f07-provider-v1254}
test ! -e "$out" || {
    echo 'v1254: destination already exists' >&2
    exit 2
}
mkdir -m 700 "$out"
python3 - "$build/boot.ini" "$build/kcore.map" "$out" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
mapping = {}
for line in Path(sys.argv[2]).read_text().splitlines():
    fields = line.split()
    if len(fields) > 1:
        try:
            int(fields[1], 8)
        except ValueError:
            continue
        mapping[fields[0]] = fields[1]
required = ('fs_provider_ready', 'fs_provider_wait_event_v917',
            'drm236_active_request', 'drm236_pending_request',
            'storage_state', 'proc_timer_clock', 'proc_current_slot',
            'proc_sched_cursor', 'proc_runq_head', 'proc_high_slot',
            'proc_table')
missing = sorted(set(required) - set(mapping))
if missing:
    raise SystemExit('v1254: missing source symbols: ' + ','.join(missing))
anchor = 'go 020\n'
if source.count(anchor) != 1:
    raise SystemExit('v1254: boot.ini has unexpected GO sequence')
folder = Path(sys.argv[3])
checkpoint = folder / 'guest-v1254.sav'
lines = [anchor, 'save %s\n' % checkpoint,
         'examine PIH\n', 'examine PIE\n', 'examine PIR\n',
         'examine PIENB\n', 'examine PIHOLD\n',
         'examine CLK\n', 'examine CLKEN\n']
with (folder / 'addresses-v1254.txt').open('w') as out:
    for name in required:
        lines.append('examine %s\n' % mapping[name])
        out.write('%s %s\n' % (name, mapping[name]))
    for name in ('drm236_active_request', 'drm236_pending_request'):
        address = int(mapping[name], 8)
        for offset in (1, 2):
            lines.append('examine %o\n' % (address + offset))
    # Read-only snapshots of actual process-private event words established
    # in the preceding v1253 guest, not assumed to recur at these addresses.
    # The saved RAM image allows correct post-stop pointer following.
Path(folder / 'boot-v1254.ini').write_text(source.replace(anchor,
                                                 ''.join(lines), 1))
PY
printf 'v1254: guest: %s\n' "$build"
printf 'v1254: snapshot dir: %s\n' "$out"
printf 'v1254: interrupt simulator only after workload reaches desired stage\n'
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s 900s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$out/boot-v1254.ini") > "$out/simh-v1254.log" 2>&1
rc=$?
set -e
printf 'v1254: simulator exit: %d\n' "$rc"
test -s "$out/guest-v1254.sav" || {
    echo 'v1254: no read-only CPU/memory checkpoint was created' >&2
    exit 1
}
if grep -aFq '?RT' "$out/simh-v1254.log" || \
        ! grep -aFq '<+' "$out/simh-v1254.log"; then
    echo 'v1254: invalid root media or no concurrent RUN progress' >&2
    exit 1
fi
grep -aE '^<|Simulation stopped|Goodbye' "$out/simh-v1254.log" | tail -8
printf 'v1254: retained checkpoint: %s\n' "$out/guest-v1254.sav"
