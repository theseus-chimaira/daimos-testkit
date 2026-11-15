#!/bin/sh
# Full-profile persistent MEMFS: fresh PDP-6 process and RAM on each
# boot, same untouched DSK and AUXSTORE DR images between HALT/restart.
# Never rebuild between boots. Failure-injection will be a later gate.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
size=${XIP_V1477_SIZE:-128}
case "$size" in
    128) core=0400000 ;;
    192) core=0600000 ;;
    256) core=01000000 ;;
    *) echo "v1477: unsupported physical RAM size $size" >&2; exit 2 ;;
esac
work="${XIP_V1477_WORK:-$TMPDIR/daimos-memfs-snapshot-v1477-$size}"
mkdir -p "$work"
trap 'if [ "${XIP_V1477_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v1477 evidence: $work"; fi' EXIT HUP INT TERM
printf '# DAIMOS FSTAB V1 - V1477 SNAPSHOT TEST\nMEMFS:/TEMP:4096:PERSIST\n' > "$work/fstab-v1477.txt"

# The first boot must start with freshly formatted AUXSTORE backing.
# Reusing a previous diagnostic workspace's DR0 would make the second
# boot's persistent state ambiguous and can hide snapshot mount defects.
rm -rf "$work/guest/build/system/boot/pdp6/drum"
XIP_V1469_WORK="$work/guest" XIP_V1469_KEEP=1 \
XIP_V1474_REMOUNT_MODE="${XIP_V1485_CORRUPT_MODE:-0}" \
XIP_V1477_TEST_CFLAGS="-DXIP_SNAPSHOT_V1477=1 ${XIP_V1478_TEST_CFLAGS:-}" \
XIP_V1477_FSTAB_TEXT="$work/fstab-v1477.txt" \
XIP_V1477_IMAGE_ONLY=1 \
XIP_V1470_BOOT_CORE_WORDS="$core" XIP_V1470_SIMH_CPU_KWORDS="$size" \
    sh "$self/daimos-xip-launch-v1469.sh"

boot="$work/guest/build/system/boot/pdp6"
if [ "${XIP_V1581_P1C_SNAPFAULT:-0}" = 1 ]; then
    # Read five real linked KCORE witness words only after the simulator
    # reaches the fatal BACKSTORE HALT. Keep the original physical boot.
    python3 - "$boot/boot.ini" "$boot/kcore.map" <<'PYV1581'
from pathlib import Path
import os
import sys

ini, mapping = (Path(s) for s in sys.argv[1:])
symbols = {}
for line in mapping.read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2 and all(c in '01234567' for c in parts[1]):
        symbols[parts[0]] = int(parts[1], 8)
names = ('daimos_v1581_pi2_errors', 'daimos_v1581_relative',
         'daimos_v1581_target_group', 'daimos_v1581_target_descriptor',
         'daimos_v1581_arm', 'backstore_blocks_used',
         'backstore_enabled', 'mfsdev_storage_errors')
assert all(name in symbols for name in names), 'v1581 KCORE map incomplete'
symbols['daimos_v1581_drm_errors'] = symbols['mfsdev_storage_errors'] + 5
names += ('daimos_v1581_drm_errors',)
if os.environ.get('XIP_V1583_VOLUME_DRM') == '1':
    names += ('volume_data_blocks', 'backing_region_count',
              'device_region_map', 'backstore_blocks',
              'mfsdev_d6set_members', 'vfs_namespace_root')
source = ini.read_text()
assert source.endswith('go 020\nexit\n'), 'v1581 boot control flow drift'
checks = ''.join('ex %06o\n' % symbols[name] for name in names)
ini.write_text(source[:-5] + checks + 'exit\n')
(ini.parent / 'v1581-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (name, symbols[name]) for name in names))
PYV1581
fi
if [ "${XIP_V1584_P1C_OVERLAP:-0}" = 1 ]; then
    # Only the disposable KCORE exports these four physical witnesses;
    # the ordinary snapshot, v1581 and v1583 cases are unaffected.
    python3 - "$boot/boot.ini" "$boot/kcore.map" <<'PYV1584'
from pathlib import Path
import sys
ini, mapping = (Path(s) for s in sys.argv[1:])
symbols = {}
for line in mapping.read_text().splitlines():
    words = line.split()
    if len(words) >= 2 and all(c in '01234567' for c in words[1]):
        symbols[words[0]] = int(words[1], 8)
names = ('daimos_v1584_snapshot_live', 'daimos_v1584_swap_started',
         'daimos_v1584_swap_completed', 'daimos_v1584_swap_reads',
         'daimos_v1584_swap_pi2', 'daimos_v1584_snapshot_pi2',
         'daimos_v1584_swap_target', 'daimos_v1584_swap_read_active',
         'daimos_v1584_last_slot', 'backstore_blocks_used',
         'volume_data_blocks', 'backing_region_count',
         'mfsdev_storage_errors', 'proc_swap_blocks_used')
assert all(name in symbols for name in names), 'v1584 missing linked witness'
source = ini.read_text()
assert source.endswith('go 020\nexit\n')
ini.write_text(source[:-5] + ''.join('ex %06o\n' % symbols[name]
                                   for name in names) + 'exit\n')
(ini.parent / 'v1584-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (name, symbols[name]) for name in names))
PYV1584
fi
if [ "${XIP_V1585_P1C_TIMED_WAKE:-0}" = 1 ]; then
    # Exact original PI6 wakeup witness from the disposable kernel.  This
    # extends (not replaces) the v1584 physical snapshot / swap probes.
    python3 - "$boot/boot.ini" "$boot/kcore.map" <<'PYV1585'
from pathlib import Path
import sys
ini, mapping = (Path(s) for s in sys.argv[1:])
symbols = {}
for line in mapping.read_text().splitlines():
    fields = line.split()
    if len(fields) >= 2 and all(c in '01234567' for c in fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
names = ('daimos_v1585_slot', 'daimos_v1585_armed',
         'daimos_v1585_woke', 'daimos_v1585_start_tick',
         'daimos_v1585_end_tick')
assert all(name in symbols for name in names), 'v1585 missing actual labels'
source = ini.read_text()
assert source.endswith('exit\n'), 'v1585 SIMH boot tail changed'
ini.write_text(source[:-5] + ''.join('ex %06o\n' % symbols[n]
                                   for n in names) + 'exit\n')
(ini.parent / 'v1585-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (n, symbols[n]) for n in names))
PYV1585
fi
if [ "${XIP_V1586_P1C_SWAP_READ_FAULT:-0}" = 1 ]; then
    # The original Type-236 error counter lives at +5 from the fixed
    # MFSDEV error base. The three additional words are test-only.
    python3 - "$boot/boot.ini" "$boot/kcore.map" <<'PYV1586'
from pathlib import Path
import sys
ini, mapping = (Path(s) for s in sys.argv[1:])
symbols = {}
for line in mapping.read_text().splitlines():
    fields = line.split()
    if len(fields) >= 2 and all(c in '01234567' for c in fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
names = ('daimos_v1586_fault_armed', 'daimos_v1586_fault_count',
         'daimos_v1586_target_group', 'backstore_enabled',
         'mfsdev_d6set_members', 'device_region_map',
         'vfs_namespace_root')
assert all(name in symbols for name in names), 'v1586 missing linked labels'
symbols['daimos_v1586_original_drm_errors'] = \
    symbols['mfsdev_storage_errors'] + 5
names += ('daimos_v1586_original_drm_errors',)
source = ini.read_text()
assert source.endswith('exit\n'), 'v1586 SIMH boot tail changed'
ini.write_text(source[:-5] + ''.join('ex %06o\n' % symbols[name]
                                   for name in names) + 'exit\n')
(ini.parent / 'v1586-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (name, symbols[name]) for name in names))
PYV1586
fi
if [ "${XIP_V1587_P1C_MM_PIN_FAIL:-0}" = 1 ]; then
    # Linked, original post-HALT words captured by the disposable
    # pre-I/O transaction observer; no production fixed-RAM allocation.
    python3 - "$boot/boot.ini" "$boot/kcore.map" <<'PYV1587'
from pathlib import Path
import sys
ini, mapping = (Path(s) for s in sys.argv[1:])
symbols = {}
for line in mapping.read_text().splitlines():
    fields = line.split()
    if len(fields) >= 2 and all(c in '01234567' for c in fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
names = (
    'fault_armed', 'pin_refusals', 'rollback_count', 'term_events',
    'slot', 'allocated_base', 'mm_before', 'mm_after',
    'owner_before', 'owner_after', 'backing_before', 'backing_after',
    'bitmap_words', 'bitmap_differences', 'record_before', 'record_after',
    'process_before', 'process_after', 'process_word1_before',
    'process_word1_after', 'process_word2_before', 'process_word2_after',
    'bcache_state_before', 'bcache_state_after',
    'bcache_tag_before', 'bcache_tag_after',
    'bcache_private_before', 'bcache_private_after',
    'storage_expect_after', 'extent_still_present',
)
names = tuple('daimos_v1587_' + name for name in names)
assert all(name in symbols for name in names), 'v1587 missing linked witness'
source = ini.read_text()
assert source.endswith('exit\n'), 'v1587 boot control drift'
ini.write_text(source[:-5] + ''.join('ex %06o\n' % symbols[name]
                                   for name in names) + 'exit\n')
(ini.parent / 'v1587-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (name, symbols[name]) for name in names))
PYV1587
fi
if [ "${XIP_V1588_P1C_POSTREAD_FREE_FAIL:-0}" = 1 ]; then
    # Test-only: examine real original MM/bitmap/process/BCACHE state
    # captured on both sides of a post-DMA checked release refusal.
    python3 - "$boot/boot.ini" "$boot/kcore.map" <<'PYV1588'
from pathlib import Path
import sys
ini, mapping = (Path(s) for s in sys.argv[1:])
symbols = {}
for line in mapping.read_text().splitlines():
    fields = line.split()
    if len(fields) >= 2 and all(c in '01234567' for c in fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
names = (
    'fault_armed', 'release_refusals', 'rollback_count', 'term_events',
    'slot', 'allocated_base', 'mm_before', 'mm_after',
    'owner_before', 'owner_after', 'backing_before', 'backing_after',
    'bitmap_words', 'bitmap_differences', 'record_before', 'record_after',
    'process_before', 'process_after', 'process_word1_before',
    'process_word1_after', 'process_word2_before', 'process_word2_after',
    'bcache_state_before', 'bcache_state_after',
    'bcache_tag_before', 'bcache_tag_after',
    'bcache_private_before', 'bcache_private_after',
    'storage_expect_after', 'extent_still_present', 'in_request',
)
names = tuple('daimos_v1588_' + name for name in names)
assert all(name in symbols for name in names), 'v1588 absent linked witness'
source = ini.read_text()
assert source.endswith('exit\n'), 'v1588 SIMH boot tail changed'
ini.write_text(source[:-5] + ''.join('ex %06o\n' % symbols[name]
                                   for name in names) + 'exit\n')
(ini.parent / 'v1588-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (name, symbols[name]) for name in names))
PYV1588
fi
if [ "${XIP_V1583_VOLUME_DRM:-0}" = 1 ]; then
    # Drum unit zero is now the selected D6FS VOLUME member, NOT an
    # AUXSTORE descriptor. Check all four real root images instead.
    for unit in 0 1 2 3; do
        test -s "$boot/drum/dsk$unit.dsk"
        grep -Fq "attach -q dr$unit $boot/drum/dsk$unit.dsk" \
            "$boot/boot.ini"
    done
    grep -Eq '^deposit SW 3$' "$boot/boot.ini"
    "$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$boot/drum" \
        > "$work/volume-fsck-before-v1583.log" 2>&1
    # The test deliberately ends with an abrupt critical HALT, so D6FS
    # superblocks can legitimately remain DIRTY. Preserve exact physical
    # per-member layouts instead of treating that expected state as damage.
    python3 - "$boot/drum" "$work/volume-descriptors-v1583.bin" <<'PYV1583'
from pathlib import Path
import sys
root, output = (Path(s) for s in sys.argv[1:])
descriptors = []
for i in range(4):
    with (root / ('dsk%d.dsk' % i)).open('rb') as image:
        descriptors.append(image.read(1024))
assert all(len(block) == 1024 for block in descriptors)
output.write_bytes(b''.join(descriptors))
PYV1583
else
    "$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
        > "$work/auxstore-v1477.inspect"
fi
for n in 1 2; do
    case "$n" in
        1) marker=XIP-SNAPSHOT-WRITTEN ;;
        2) marker=XIP-SNAPSHOT-RESTORED ;;
    esac
    if [ "$n" = 2 ] && [ "${XIP_V1485_CORRUPT_MODE:-0}" = 1 ]; then
        python3 "$self/daimos-memfs-snapshot-corrupt-v1485.py" \
            "$work/auxstore-v1477.inspect" "$boot/drum/dsk0.dsk"
        marker=XIP-SNAPSHOT-CORRUPT-RECOVERED
    fi
    if [ "${XIP_V1580_P1C_SWAP:-0}" = 1 ]; then
        # The source-authentic privileged syscall HALTs inside the same
        # process which created the sleeping swapped children. No shell
        # second HALT or successful-status echo may intervene.
        cat > "$work/boot-$n.probes" <<EOF
probe memfs-swapped-halt-$n
command /CONFIG/XIP1469.TEST
contains $marker
contains P1C-LOGSTORE-APPEND-READBACK
contains P1C-SWAP-CHILDREN-SLEEP-V1580
contains P1C-SWAP-HALT-REQUEST-V1580
not_contains XIP-FAIL-
terminal eof
end
EOF
        if [ "$n" = 2 ]; then
            sed -i '/^contains P1C-LOGSTORE-APPEND-READBACK$/a contains P1C-LOGSTORE-PREVIOUS-BOOT' \
                "$work/boot-$n.probes"
        fi
    else
    cat > "$work/boot-$n.probes" <<EOF
probe memfs-persistent-boot-$n
command /CONFIG/XIP1469.TEST; ECHO STATUS:\$?
contains $marker
contains STATUS:0
not_contains XIP-FAIL-
end
probe orderly-halt-$n
command HALT
terminal eof
end
EOF
    fi
    if [ "${XIP_V1578_P1C_ORPHAN:-0}" = 1 ]; then
        if [ "$n" = 1 ]; then
            sed -i "/^contains $marker$/a contains P1C-ORPHAN-LEFT-UNCOMMITTED" \
                "$work/boot-$n.probes"
        else
            sed -i "/^contains $marker$/a contains P1C-ORPHAN-IGNORED" \
                "$work/boot-$n.probes"
            sed -i "/^contains P1C-ORPHAN-IGNORED$/a contains P1C-LOGSTORE-APPEND-READBACK" \
                "$work/boot-$n.probes"
        fi
    elif [ "${XIP_V1576_P1C_LOGSTORE:-0}" = 1 ] &&
        [ "${XIP_V1580_P1C_SWAP:-0}" != 1 ]; then
        sed -i "/^contains $marker$/a contains P1C-LOGSTORE-APPEND-READBACK" \
            "$work/boot-$n.probes"
        if [ "$n" = 2 ]; then
            sed -i "/^contains P1C-LOGSTORE-APPEND-READBACK$/a contains P1C-LOGSTORE-PREVIOUS-BOOT" \
                "$work/boot-$n.probes"
        fi
    fi
    if [ "${XIP_V1478_FAULT_MODE:-0}" = 1 ]; then
        sed -i "/^contains $marker$/a contains XIP-SNAPSHOT-HALT-REFUSED" \
            "$work/boot-$n.probes"
    fi
    printf '=== v1477 physical %sK, cold boot %s: %s ===\n' "$size" "$n" "$marker"
    timeout_v1477=90
    timeout_snapshot_v1585=
    if [ "${XIP_V1584_P1C_OVERLAP:-0}" = 1 ]; then
        timeout_v1477=180
    fi
    if [ "${XIP_V1585_P1C_TIMED_WAKE:-0}" = 1 ]; then
        # This scenario transfers hundreds of additional genuine 128-word
        # drum blocks while snapshotting. Give a slow PDP-6 simulator more
        # time than the v1584 no-overlap probe, but still fail boundedly
        # and retain the real CPU/PC history on an actual stall.
        timeout_v1477=300
        timeout_snapshot_v1585=--timeout-snapshot
    fi
    "$self/../../tools/daimos-simh-harness-v6.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$boot/boot.ini" \
        --pty-run "$work/guest/pty-run" --login ROOT \
        --probes "$work/boot-$n.probes" \
        --work-dir "$work/boot-$n" --boot-timeout 60 \
        --timeout "$timeout_v1477" $timeout_snapshot_v1585
    log="$work/boot-$n/simh.log"
    grep -Eq "^MEM[[:space:]]+$size K" "$log"
    grep -Eq '^MEMFS[[:space:]]+LOADED' "$log"
    grep -Fq "$marker" "$log"
    if [ "$n" = 2 ] && [ "${XIP_V1485_CORRUPT_MODE:-0}" = 1 ]; then
        grep -Fq 'INIT: MOUNTALL FAILED' "$log" || {
            echo 'v1485: corrupt metadata unexpectedly accepted' >&2
            exit 1
        }
    elif grep -Fq 'INIT: MOUNTALL FAILED' "$log"; then
        echo "v1477: persistent MEMFS failed to mount on cold boot $n" >&2
        exit 1
    fi
    if [ "${XIP_V1580_P1C_SWAP:-0}" != 1 ]; then
        grep -q '^STATUS:0' "$log"
    else
        grep -Fq 'P1C-SWAP-HALT-REQUEST-V1580' "$log"
        if grep -Fq 'XIP-FAIL-' "$log"; then
            echo "v1580: swap-armed snapshot guest failed" >&2
            exit 1
        fi
    fi
    # v1484: a raw-MRES LOGSTORE ABI mismatch once DMA-wrote KCORE text
    # into DR0 block zero during INIT/LOGIN, corrupting AUXSTORE discovery
    # on the next boot despite a valid snapshot near the end of the drum.
    # Refuse the guest immediately if any boot changed the raw descriptor.
    if [ "${XIP_V1583_VOLUME_DRM:-0}" = 1 ]; then
        python3 - "$boot/drum" "$work/volume-descriptors-v1583.bin" <<'PYV1583'
from pathlib import Path
import sys
root, baseline = (Path(s) for s in sys.argv[1:])
descriptors = []
for i in range(4):
    with (root / ('dsk%d.dsk' % i)).open('rb') as image:
        descriptors.append(image.read(1024))
assert all(len(block) == 1024 for block in descriptors)
current = b''.join(descriptors)
assert current == baseline.read_bytes(), \
    'v1583: one of four physical D6FSR2 member layouts was damaged'
PYV1583
    else
        "$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
            > "$work/auxstore-after-boot-$n.inspect" || {
            echo "v1484: AUXSTORE drum descriptor was damaged by guest boot $n" >&2
            exit 1
        }
        cmp -s "$work/auxstore-v1477.inspect" \
            "$work/auxstore-after-boot-$n.inspect" || {
            echo "v1484: AUXSTORE partition geometry changed at boot $n" >&2
            exit 1
        }
    fi
    if [ "$n" = 1 ] && {
        [ "${XIP_V1581_P1C_SNAPFAULT:-0}" = 1 ] ||
        [ "${XIP_V1586_P1C_SWAP_READ_FAULT:-0}" = 1 ]; }; then
        # One real physical fail-stop. A second boot would deliberately
        # find no committed snapshot, not the v1580 recovery baseline.
        break
    fi
    if [ "$n" = 1 ] && [ "${XIP_V1580_P1C_SWAP:-0}" = 1 ]; then
        if [ "${XIP_V1583_VOLUME_DRM:-0}" != 1 ]; then
            python3 "$self/daimos-p1c-swapped-media-v1580.py" \
                "$boot/drum/dsk0.dsk" "$work/auxstore-after-boot-$n.inspect" \
                "$work/swapped-physical-v1580.txt"
        fi
    fi
    if [ "$n" = 1 ] && [ "${XIP_V1578_P1C_ORPHAN:-0}" = 1 ]; then
        python3 "$self/daimos-p1c-orphan-media-v1578.py" \
            "$boot/drum/dsk0.dsk" "$work/auxstore-after-boot-$n.inspect" \
            "$work/orphan-physical-v1578.txt"
    fi
done
if [ "${XIP_V1586_P1C_SWAP_READ_FAULT:-0}" = 1 ]; then
    echo 'v1586: selected physical swap READ PI2 fatal boot finished; snapshot not committed'
elif [ "${XIP_V1581_P1C_SNAPFAULT:-0}" = 1 ]; then
    echo 'v1581: one physical fatal-fault boot finished; commit not claimed'
else
    echo 'PASS v1477: committed MEMFS snapshot survived a completely new PDP-6 boot'
fi
