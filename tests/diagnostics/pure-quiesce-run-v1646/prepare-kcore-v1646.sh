#!/bin/sh
# Build a disposable KCORE with the accepted v1565 real scheduler interval.
# Production source stays untouched. The inserted delay does not replace
# any owner admission, mount retirement or provider completion operation.
set -eu
: "${DAIMOS_REPO:?original source required}"
: "${PURE_QUIESCE_BASE_V1646:?source-built 48K guest build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-quiesce-v1646.XXXXXX")
trap 'echo "v1646 disposable KCORE and original user media: $work"' EXIT HUP INT TERM
mkdir -p "$work/build" "$work/user"
cp -a "$PURE_QUIESCE_BASE_V1646/." "$work/build/"
base_parent=$(CDPATH= cd -- "$PURE_QUIESCE_BASE_V1646/.." && pwd)
cp "$base_parent/user/init.dxr" "$work/user/init.dxr"

python3 - "$DAIMOS_REPO/system/kernel/fs/vfs.s" \
    "$work/build/kcore-asm/vfs.s" <<'PY'
from pathlib import Path
import sys

original = Path(sys.argv[1]).read_text(encoding="ascii")
copied = Path(sys.argv[2])
assert copied.read_text(encoding="ascii") == original, \
    "disposable base VFS assembly not identical to production source"
old = ("        movem   1,-2(17)               ; 1 for V2, zero otherwise\n"
       "        move    1,-1(17)\n"
       "        pushj   17,vfs_sync\n")
assert original.count(old) == 1
replacement = (
    "        movem   1,-2(17)               ; 1 for V2, zero otherwise\n"
    "        ; v1646 TEST ONLY: real 60Hz scheduler sleep AFTER the\n"
    "        ; actual V2 owner-quiescence bit is acquired. Never edit\n"
    "        ; original VFS owner/admission or unmount transaction.\n"
    "        .globl vfs_quiesce_sleep_done_v1646\n"
    "        skipn   -2(17)\n"
    "        jrst    vfs_quiesce_sleep_done_v1646\n"
    "        movei   1,01400               ; 768 real PI6 clock ticks\n"
    "        pushj   17,proc_sleep_ticks\n"
    "vfs_quiesce_sleep_done_v1646:\n"
    "        move    1,-1(17)\n"
    "        pushj   17,vfs_sync\n")
copied.write_text(".globl proc_sleep_ticks\n" +
                  original.replace(old, replacement, 1), encoding="ascii")
print("v1646: disposable original-source V2 quiescence interval staged")
PY

boot="$work/build"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED=1 \
    SYSTEM_INIT_DXR="$work/user/init.dxr" \
    >"$work/image-build-v1646.log" 2>&1 || {
        tail -80 "$work/image-build-v1646.log" >&2
        exit 1
    }

grep -q '^vfs_quiesce_sleep_done_v1646[[:space:]]' "$boot/kcore.map"
grep -q '^proc_swap_attach[[:space:]]' "$boot/kcore.map"
grep -q '^vfs_dtfs_owner_admit_v1562[[:space:]]' "$boot/kcore.map"
grep -q '^vfs_dtfs_quiesce_begin_v1562[[:space:]]' "$boot/kcore.map"
test -s "$boot/kcore.stream"
test -s "$boot/kinit.lowmem.words"

# Regenerate the real three-member TSFS boot source because KCORE's
# original low-memory payload changed address with this test-only call.
# The real compressed DXR is independently recreated from the exact
# unchanged source-linked userland INIT rather than copied from the
# previous boot's possibly stale media.
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
sh "$testkit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh" \
    "$work" "$boot" >"$work/tsfs-media-v1646.log" 2>&1 || {
        tail -60 "$work/tsfs-media-v1646.log" >&2
        exit 1
    }
test -s "$boot/media/dtc0.tap" && test -s "$boot/media/dtc3-home-v22.tap"
echo "PASS v1646: original source-matched 48K copied KCORE with only v1565-style scheduling delay"
echo "v1646: staged build=$boot"
