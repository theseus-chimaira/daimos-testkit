#!/bin/sh
# Full PDP-6 KCC disk-root boot: privileged, pinned raw MEMFS XIP RUN/EXEC.
set -eu
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${TMPDIR:?set TMPDIR}"

# v1479: XIP requires MEMFS, which is disabled below 96K. Do not build
# low-memory XIP guests; 32K/48K release tests are non-XIP only.
xip_guard_kwords=${XIP_V1470_SIMH_CPU_KWORDS:-256}
case "$xip_guard_kwords" in
    ''|*[!0-9]*)
        echo 'XIP requires a numeric physical memory size in Kwords' >&2
        exit 2 ;;
esac
if [ "$xip_guard_kwords" -lt 96 ]; then
    echo 'XIP requires MEMFS and at least 96K physical memory' >&2
    exit 2
fi

tag=daimos-xip-launch-v1469
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="${XIP_V1469_WORK:-$TMPDIR/$tag-$$}"
obj="$work/obj"
build="$work/build"
mkdir -p "$obj"
trap 'if [ "${XIP_V1469_KEEP:-0}" != 1 ]; then rm -rf "$work"; else printf "XIP evidence: %s\n" "$work"; fi' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core"
incs="$incs -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs"
incs="$incs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules"
incs="$incs -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage"
incs="$incs -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"

"$das" -F -C -O "$obj/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$obj/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
if [ "${XIP_V1474_REMOUNT_MODE:-0}" = 1 ]; then
    "$das" -F -C -O "$obj/memfs-mount-v1474.dobj" \
        "$DAIMOS_REPO/userland/init/memfs_mount.s"
    xip_extra_veneer="$obj/memfs-mount-v1474.dobj"
else
    xip_extra_veneer=
fi
"$cc" -std=c89 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$obj/u.s"
"$das" -F -C -O "$obj/u.dobj" "$obj/u.s"
"$cc" -std=c89 -Os ${XIP_V1472_TEST_CFLAGS:-} ${XIP_V1473_TEST_CFLAGS:-} ${XIP_V1474_TEST_CFLAGS:-} ${XIP_V1477_TEST_CFLAGS:-} $incs -S "$self/$tag.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
    "$obj/crt0.dobj" "$obj/syscall.dobj" $xip_extra_veneer "$obj/u.dobj" \
    "$obj/test.dobj" "$libgcc"

# D6FS_EXTRA_ARGS is a command-line list, not a Makefile file dependency.
# A retained diagnostic workspace must always carry the freshly linked
# XIP probe, never a stale earlier DXR in its already-populated DSK media.
if [ -n "${XIP_V1469_WORK:-}" ]; then
    rm -f "$build/system/boot/pdp6/disk/dsk0.dsk" \
        "$build/system/boot/pdp6/disk/dsk1.dsk" \
        "$build/system/boot/pdp6/disk/dsk2.dsk" \
        "$build/system/boot/pdp6/disk/dsk3.dsk"
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/pty-run" \
    "$self/../../tools/pty-run-v1.c"
cat > "$work/probes.txt" <<'PROBES'
probe real-root-xip-run-exec
command /CONFIG/XIP1469.TEST; ECHO STATUS:$?
contains XIP-RUN-PASS
contains STATUS:0
not_contains XIP-FAIL-
end
probe orderly-halt
command HALT
terminal eof
end
PROBES
if [ "${XIP_V1594_P1D_DSK_FSINFO:-0}" = 1 ]; then
    # Accept only evidence from the actual DSK270-root XIP guest.
    sed -i '/^contains XIP-RUN-PASS$/a contains P1D-D6FS-DSK-CAPACITY6-V1594' \
        "$work/probes.txt"
fi
if [ "${XIP_V1597_P1D_NO_DRM:-0}" = 1 ]; then
    sed -i '/^contains XIP-RUN-PASS$/a contains P1D-D6FS-NODRM-CAPACITY2-V1597' \
        "$work/probes.txt"
fi
if [ "${XIP_V1601_P1D_NO_DSK:-0}" = 1 ]; then
    sed -i '/^contains XIP-RUN-PASS$/a contains P1D-D6FS-NODSK-CAPACITY2-V1601' \
        "$work/probes.txt"
fi
if [ "${XIP_V1472_FAULT_MODE:-0}" = 1 ]; then
    sed -i '/^contains XIP-RUN-PASS$/a contains XIP-UAREA-FAULT-PASS' \
        "$work/probes.txt"
fi
if [ "${XIP_V1473_PRESSURE_MODE:-0}" = 1 ]; then
    sed -i '/^contains XIP-RUN-PASS$/a contains XIP-PRESSURE-PASS' \
        "$work/probes.txt"
fi
if [ "${XIP_V1474_REMOUNT_MODE:-0}" = 1 ]; then
    sed -i '/^contains XIP-RUN-PASS$/a contains XIP-REMOUNT-PASS' \
        "$work/probes.txt"
fi

if [ "${XIP_V1475_FAULT_MODE:-0}" = 1 ]; then
    sed -i '/^contains XIP-RUN-PASS$/a contains XIP-REMOUNT-REFUSAL-PASS' \
        "$work/probes.txt"
fi

host_tools="${DAIMOS_HOST_TOOLS:-$PDP10_PREFIX/bin}"
# v1470: memory-specific full-profile XIP acceptance. MEMFS is not
# available on the lowmem profile, so 128K/192K/256K runs use the same
# full resident module selection and the physical core-size-specific image.
xip_boot_core_words=${XIP_V1470_BOOT_CORE_WORDS:-01000000}
xip_simh_cpu_kwords=${XIP_V1470_SIMH_CPU_KWORDS:-256}
# v1583 opt-in: reuse the same exact XIP workload with the production
# four-member Type-236 root. All earlier tests retain DSK + AUXSTORE.
if [ "${XIP_V1583_VOLUME_DRM:-0}" = 1 ]; then
    xip_root_args='BOOT=drm ROOT=drum ROOTSET=1'
else
    xip_root_args='BOOT=dsk ROOT=disk ROOTSET=1'
fi
PATH="$host_tools:$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    KERNEL_DIR="${XIP_V1478_KERNEL_DIR:-${XIP_V1475_KERNEL_DIR:-${XIP_V1472_KERNEL_DIR:-$DAIMOS_REPO/system/kernel}}}" \
    HOST_TOOLS="$host_tools" DAS_REPO="${DAS_REPO:-$DAIMOS_REPO/../das}" \
    KCC_REPO="${KCC_REPO:-$DAIMOS_REPO/../kcc}" \
    SYSTEM_FSTAB_TEXT="${XIP_V1477_FSTAB_TEXT:-$DAIMOS_REPO/userland/config/fstab}" \
    BOOT_PROFILE=full COMPILER=kcc \
    BOOT_CORE_WORDS="$xip_boot_core_words" \
    SIMH_CPU_KWORDS="$xip_simh_cpu_kwords" \
    $xip_root_args \
    D6FS_EXTRA_ARGS="-f /CONFIG/XIP1469.TEST:$obj/test.dxr:555:dxr" \
    > "$work/image-build.log" 2>&1 || {
        tail -65 "$work/image-build.log" >&2
        printf 'XIP image build failure; evidence: %s\n' "$work" >&2
        exit 1
    }

if [ "${XIP_V1477_IMAGE_ONLY:-0}" = 1 ]; then
    echo "PASS v1477: persistent MEMFS image built (no SIMH boot yet)"
    exit 0
fi

if [ "${XIP_V1597_P1D_NO_DRM:-0}" = 1 ]; then
    # Change ONLY the private simulator startup config. Physical 236
    # drum hardware is wholly absent before MINIT probes its CONI PI.
    # Do not alter KCORE's installed module-services or FSINFO words.
    python3 - "$build/system/boot/pdp6/boot.ini" <<'PYV1597'
from pathlib import Path
import re
import sys

ini = Path(sys.argv[1])
lines = ini.read_text().splitlines(keepends=True)
assert sum(line.strip().lower() == 'set dr enabled'
           for line in lines) == 1
# The real MINIT probe is CONO/CONI device 0010 on the Type-167
# DP I/O processor, NOT a query of the Type-236 DR unit array.
assert sum(line.strip().lower() == 'set dp enabled'
           for line in lines) == 1
assert sum(bool(re.match(r'attach -q dr[0-3] ', line, re.I))
           for line in lines) == 4
out = []
absent = 0
for line in lines:
    if line.strip().lower() == 'set dr enabled':
        out.append('set dr disabled\n')
        absent += 1
    elif line.strip().lower() == 'set dp enabled':
        out.append('set dp disabled\n')
        absent += 1
    elif re.match(r'set dr[0-3] (enabled|writeenabled)', line, re.I):
        continue
    elif re.match(r'attach -q dr[0-3] ', line, re.I):
        continue
    else:
        out.append(line)
assert absent == 2
ini.write_text(''.join(out))
(ini.parent / 'v1597-no-drm-boot.txt').write_text(
    'set dp disabled\nset dr disabled\n')
PYV1597
fi
if [ "${XIP_V1601_P1D_NO_DSK:-0}" = 1 ]; then
    # A DRM-selected root must remain bootable without a Type-136
    # DSK270 controller.  Disable the actual simulator device and
    # remove its attachments before the original KINIT MINIT probe.
    python3 - "$build/system/boot/pdp6/boot.ini" <<'PYV1601'
from pathlib import Path
import re
import sys

ini = Path(sys.argv[1])
lines = ini.read_text().splitlines(keepends=True)
assert sum(line.strip().lower() == 'set dsk enabled'
           for line in lines) == 1, 'missing actual DSK controller enable'
assert sum(bool(re.match(r'attach -q dsk[0-3] ', line, re.I))
           for line in lines) == 4, 'expected four physical DSK images'
assert 'deposit SW 3\n' in lines, 'not a DRM-selected root'
assert 'set dp enabled\n' in lines and 'set dr enabled\n' in lines
out = []
for line in lines:
    if line.strip().lower() == 'set dsk enabled':
        out.append('set dsk disabled\n')
    elif re.match(r'attach -q dsk[0-3] ', line, re.I):
        continue
    else:
        out.append(line)
ini.write_text(''.join(out))
(ini.parent / 'v1601-no-dsk-boot.txt').write_text(
    'set dsk disabled\nDSK0-3 unattached\nDRM0-3 attached\n')
PYV1601
    # Read original fixed KCORE addresses only after the guest HALTs.
    # Record the untouched original physical DRM member descriptors
    # *before* simulator I/O for independent post-boot comparison.
    python3 - "$build/system/boot/pdp6" <<'PYV1601BASE'
from pathlib import Path
import re
import sys

boot = Path(sys.argv[1])
descriptors = []
for unit in range(4):
    image = boot / 'drum' / ('dsk%d.dsk' % unit)
    with image.open('rb') as stream:
        block = stream.read(1024)
    assert len(block) == 1024, 'incomplete real DRM member descriptor'
    descriptors.append(block)
(boot / 'v1601-original-drm-descriptors.bin').write_bytes(
    b''.join(descriptors))
mapping = (boot / 'kcore.map').read_text()
names = ('vfs_mount_limit', 'vfs_mount_root_base',
         'vfs_mount_target_base', 'vfs_namespace_root')
addresses = {}
for name in names:
    matches = re.findall(r'(?m)^' + re.escape(name) +
                         r'\s+([0-7]{6})\s*$', mapping)
    assert len(matches) == 1, 'missing unique KCORE label: ' + name
    addresses[name] = int(matches[0], 8)
ini = boot / 'boot.ini'
source = ini.read_text()
assert source.endswith('exit\n'), 'SIMH boot dofile tail changed'
ini.write_text(source[:-5] + ''.join('ex %06o\n' % addresses[name]
                                    for name in names) + 'exit\n')
(boot / 'v1601-linked-addresses.txt').write_text(
    ''.join('%s %06o\n' % (name, addresses[name]) for name in names))
PYV1601BASE
fi

# Test-only observation after HALT: the simulator's noninteractive dofile
# reads the actual fixed-KCORE counters and then closes normally.  Both
# counters live only in the isolated v1472 fault-injected KCORE copy.
if [ "${XIP_V1472_FAULT_MODE:-0}" = 1 ]; then
    python3 - "$build/system/boot/pdp6" <<'PY'
from pathlib import Path
import sys

build = Path(sys.argv[1])
values = {}
for line in (build / 'kcore.map').read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2 and parts[0] in (
        'daimos_test_uarea_failed_v1472',
        'daimos_test_unpin_rejected_v1472'):
        values[parts[0]] = parts[1]
if len(values) != 2:
    raise SystemExit('v1472: test-only KCORE counters absent')
path = build / 'boot.ini'
source = path.read_text()
if not source.endswith('exit\n'):
    raise SystemExit('v1472: no SIMH boot.ini exit command')
checks = ''.join('examine ' + values[key] + '\n'
                 for key in sorted(values))
path.write_text(source[:-5] + checks + 'exit\n')
(build / 'v1472-count-addresses').write_text(
    ''.join(key + ' ' + values[key] + '\n' for key in sorted(values)))
PY
fi

# v1475's symbol is MRES-relative, not a fixed KCORE physical address.
# Require the disposable MRES to contain it; guest outcomes prove the
# one-time refusal occurred without guessing the relocated address.
if [ "${XIP_V1475_FAULT_MODE:-0}" = 1 ]; then
    python3 "$self/daimos-xip-unmount-canary-v1476.py" \
        "$build/system/boot/pdp6/memfs-mres.map"
fi

"$self/../../tools/daimos-simh-harness-v6.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$build/system/boot/pdp6/boot.ini" \
    --pty-run "$work/pty-run" --login ROOT --probes "$work/probes.txt" \
    --work-dir "$work/run" --boot-timeout 60 --timeout 90

log="$work/run/simh.log"
# v1470: simulator configuration alone does not prove actual physical
# memory. Require the KINIT-detected installed size in the guest transcript
# as well as the live MEMFS mount and the full XIP lifecycle probe above.
if ! grep -Eq "^MEM[[:space:]]+$xip_simh_cpu_kwords K" "$log" ||
    ! grep -Eq '^MEMFS[[:space:]]+LOADED' "$log"; then
    echo "FAIL: guest did not detect ${xip_simh_cpu_kwords}K and load MEMFS" >&2
    tail -45 "$log" >&2
    exit 1
fi

printf '%s\n' 'PASS v1469: 3 serial + 3 queued XIP RUN/WAIT, malformed/nonroot/argc refusal, EXEC rollback and commit'
