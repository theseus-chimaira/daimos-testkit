#!/bin/sh
# v1472: real privileged MEMFS XIP admission, one injected RUN u-area
# allocator refusal, two injected owner-side unpin refusals and deferred
# slot-zero cleanup on an actual full-profile PDP-6 guest.
# All fault hooks live in an isolated source copy. No production patches.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="${XIP_V1472_WORK:-$TMPDIR/daimos-xip-uarea-v1472-$$}"
mkdir -p "$work/source/system" "$work/guest"
trap 'if [ "${XIP_V1472_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v1472 evidence: $work"; fi' EXIT HUP INT TERM

# Copies protect production sources. The same original KCORE/MM and MEMFS
# implementations are linked; only their two explicitly named failure
# boundaries are instrumented. The rest of the RUN/VM/slot-zero path is real.
if [ ! -f "$work/source/system/kernel/Makefile" ]; then
    cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
fi
if [ ! -f "$work/source/VERSION" ]; then
    cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
fi
if [ ! -d "$work/source/system/stand" ]; then
    cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
fi
python3 - "$work/source/system/kernel" "$DAIMOS_REPO/system/kernel" <<'PY'
from pathlib import Path
import sys

kernel = Path(sys.argv[1])
production = Path(sys.argv[2])
run = kernel / 'proc/proc_run.s'
src = (production / 'proc/proc_run.s').read_text()
target = ('        pushj   17,mm_alloc_aligned\n'
          '        move    014,-2(17)')
if src.count(target) != 1:
    raise SystemExit('v1472: u-area allocation boundary changed')
src = src.replace(target, '''        pushj   17,daimos_test_uarea_alloc_v1472
        move    014,-2(17)''', 1)
src += '''
; v1472 TEST COPY ONLY: call the real read-only MEMFS pin owner query.
; Once strict XIP admission has succeeded, inject exactly one allocator
; refusal without allocating the u-area or publishing a runnable process.
; The next RUN uses the unchanged mm_alloc_aligned entry.
        .text
        .globl fs_provider_reg_call
        .globl daimos_test_uarea_failed_v1472
daimos_test_uarea_alloc_v1472:
        skipn   daimos_test_uarea_failed_v1472
        jrst    daimos_test_uarea_check_v1472
        jrst    mm_alloc_aligned
daimos_test_uarea_check_v1472:
        push    17,1
        push    17,2
        push    17,3
        push    17,4
        hrrz    1,1(013)               ; verified staged VM physical base
        movei   6,031                  ; XIP_OWNS_BASE: read-only
        movei   7,4                    ; MEMFS
        pushj   17,fs_provider_reg_call
        move    0,1
        pop     17,4
        pop     17,3
        pop     17,2
        pop     17,1
        caie    0,1
        jrst    mm_alloc_aligned       ; non-XIP RUN unchanged
        aos     daimos_test_uarea_failed_v1472
        seto    1,                      ; injected MM_ERR_NOMEM
        popj    17,
        .bss
daimos_test_uarea_failed_v1472: .block 1
        .globl daimos_test_unpin_rejected_v1472
daimos_test_unpin_rejected_v1472: .block 1
'''
if run.read_text() != src:
    run.write_text(src)

memfs = kernel / 'fs/memfs_data_pdp6.s'
src = (production / 'fs/memfs_data_pdp6.s').read_text()
target = 'memfs_xip_unpin_base:\n        push    17,010'
if src.count(target) != 1:
    raise SystemExit('v1472: MEMFS unpin owner boundary changed')
src = src.replace(target, '''        .globl daimos_test_uarea_failed_v1472
        .globl daimos_test_unpin_rejected_v1472
memfs_xip_unpin_base:
        skipn   daimos_test_uarea_failed_v1472
        jrst    daimos_test_xip_unpin_real_v1472
        move    0,daimos_test_unpin_rejected_v1472
        caige   0,2                    ; initial refusal plus one retry
        jrst    daimos_test_xip_unpin_refuse_v1472
        jrst    daimos_test_xip_unpin_real_v1472
daimos_test_xip_unpin_refuse_v1472:
        aos     daimos_test_unpin_rejected_v1472
        seto    1,                      ; actual MEMFS ref/MM pin untouched
        popj    17,
daimos_test_xip_unpin_real_v1472:
        push    17,010''', 1)
if memfs.read_text() != src:
    memfs.write_text(src)
print('v1472: isolated u-area and pinned-XIP unpin failure hooks installed')
PY

export XIP_V1469_WORK="$work/guest"
export XIP_V1469_KEEP=1
export XIP_V1472_KERNEL_DIR="$work/source/system/kernel"
export XIP_V1472_TEST_CFLAGS=-DXIP_UAREA_FAULT_V1472=1
export XIP_V1472_FAULT_MODE=1
export XIP_V1470_BOOT_CORE_WORDS="${XIP_V1472_BOOT_CORE_WORDS:-0400000}"
export XIP_V1470_SIMH_CPU_KWORDS="${XIP_V1472_SIMH_CPU_KWORDS:-128}"
sh "$self/daimos-xip-launch-v1469.sh"

# Confirm that the injected boundary was actually crossed once and that
# both temporary MEMFS unpin refusals occurred.  The SIMH dofile samples
# fixed-KCORE counters after HALT, so a different earlier RUN rejection
# cannot accidentally satisfy the guest-only negative assertions.
python3 - "$work/guest/build/system/boot/pdp6/v1472-count-addresses" \
    "$work/guest/run/simh.log" <<'PY'
from pathlib import Path
import re
import sys

addresses = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, address = line.split()
    addresses[name] = int(address, 8)
actual = {}
for line in Path(sys.argv[2]).read_text(errors='replace').splitlines():
    match = re.match(r'^\s*([0-7]+):\s*([0-7]+)\s*$', line)
    if match is not None:
        actual[int(match.group(1), 8)] = int(match.group(2), 8)
expected = {'daimos_test_uarea_failed_v1472': 1,
            'daimos_test_unpin_rejected_v1472': 2}
for name, want in expected.items():
    seen = actual.get(addresses[name])
    if seen != want:
        raise SystemExit('v1472: ' + name + ' expected ' + str(want) +
                         ', observed ' + str(seen))
print('v1472 fixed-KCORE fault counters:', expected)
PY

# CHMOD was refused during pending PREVM rollback, became possible after
# the slot-zero reaper released the ref, and a second XIP RUN/WAIT passed.
echo "PASS v1472: injected post-XIP u-area OOM, deferred owner retry, pin release, RUN recovery"
