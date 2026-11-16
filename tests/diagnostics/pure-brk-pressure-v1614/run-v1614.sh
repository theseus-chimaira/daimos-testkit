#!/bin/sh
# Non-accepting 48K PDP-6 sleeping-owner BRK/RAW/PIPE/WAIT
# diagnostic. A physical failure must retain its console and
# MM evidence; only promote to validation after actual slot-0
# restoration and exact MM owner preservation are demonstrated.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-brk-pressure-v1614.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1614: pressure guest evidence $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/user"
cp "${PURE_BRK_SOURCE_V1615:-$here/test-v1614.c}" \
    "$work/user/init-v1614.c"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
# Build the actual DAIMOS host linker source so this test cannot
# accidentally use an older installed dlink whose PURE range check
# mistakes the PDP-10 AC register file for writable TEXT.
dlink="$work/dlink-v1614"
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$dlink" "$DAIMOS_REPO/tools/host/dlink.c" \
    "$DAIMOS_REPO/tools/host/dobj.c"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -S "$work/user/init-v1614.c" \
    -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
"$das" -C -F -O "$work/user/crt0.dobj" \
    "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
extra_obj=
if [ -n "${PURE_BRK_VENEER_V1615:-}" ]; then
    "$das" -C -F -O "$work/user/brk-cause-v1615.dobj" \
        "$PURE_BRK_VENEER_V1615"
    extra_obj="$work/user/brk-cause-v1615.dobj"
fi
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" --pure -b 020 -o "$work/user/init.dxr" \
    -M "$work/user/init.map" "$work/user/crt0.dobj" \
    "$work/user/syscall.dobj" "$work/user/init.dobj" \
    $extra_obj "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"
# A plain DXR (purity=UNKNOWN) is never eligible for RAW prefix DROP:
# reject that test-setup error before constructing any boot media.
"$PDP10_PREFIX/bin/dxrcheck" -d "$work/user/init.dxr" \
    >"$work/user/dxrcheck.log"
grep -q 'purity=PURE' "$work/user/dxrcheck.log" || {
    echo 'FAIL v1614: guest executable has no immutable PURE prefix' >&2
    exit 1
}

boot="$work/build"
# v1631 source-matched physical capacity control: an identical 48K
# guest may run with the optional PURE MRES absent. The default remains
# enabled for all historical v1614-v1630 PURE tests.
pure_enabled=${PURE_ENABLE_V1631:-1}
case "$pure_enabled" in
0|1) ;;
*) echo 'FAIL v1631: PURE_ENABLE_V1631 must be 0 or 1' >&2; exit 1 ;;
esac
# v1626 experimental 64K profile selector. Preserve the exact 48K
# historical diagnostic unless an explicit, matched 64K request is made.
pure_phys_kwords=${PURE_PHYS_KWORDS_V1626:-48}
case "$pure_phys_kwords" in
48) pure_core_words=0140000 ;;
64) pure_core_words=0200000 ;;
*) echo 'FAIL v1626: supported physical memory profiles are 48/64K' >&2
   exit 1 ;;
esac
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS="$pure_core_words" SIMH_CPU_KWORDS="$pure_phys_kwords" \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED="$pure_enabled" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" >"$work/build.log" 2>&1 || {
    tail -60 "$work/build.log" >&2
    keep=1
    exit 1
}
grep -F "F /SYSTEM/INIT $work/user/init.dxr " \
    "$boot/tsfs-root.manifest" >/dev/null
if [ "$pure_enabled" = 1 ]; then
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
else
    if grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"; then
        echo 'FAIL v1631: off-build unexpectedly includes PURE MRES' >&2
        keep=1
        exit 1
    fi
fi

awk '!/^attach -q (dsk[0-9]+|dr[0-9]+) /' \
    "$boot/boot.ini" >"$work/noaux.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' "$work/noaux.ini"; then
    echo 'FAIL v1614: pressure guest still has auxiliary media' >&2
    exit 1
fi
port=$((32000 + ($$ % 15000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/headless.ini" "$port" "$((port+14000))"

# v1615 test-only physical MM snapshot at the simulator's normal
# post-HALT monitor prompt. No breakpoint instruction overhead, no
# kernel memory reads from user mode and no production modification.
if [ "${PURE_MM_DUMP_V1615:-0}" = 1 ]; then
    python3 - "$boot/kcore.map" "$work/headless.ini" <<'PY'
from pathlib import Path
import sys
symbols={}
for line in Path(sys.argv[1]).read_text().splitlines():
    parts=line.split()
    if len(parts)>=2 and all(c in '01234567' for c in parts[1]):
        symbols[parts[0]]=int(parts[1],8)
required=('mm_extents','mm_extent_count','mm_arenas',
          'mm_arena_count','proc_current_slot','proc_high_slot')
assert all(key in symbols for key in required)
path=Path(sys.argv[2])
s=path.read_text()
assert 'go 020\nexit\n' in s
cmd='go 020\n'
for name in required:
    cmd+='examine %06o\n' % symbols[name]
cmd+='examine %06o-%06o\n' % (symbols['mm_arenas'],
                             symbols['mm_arenas']+7)
cmd+='examine %06o-%06o\n' % (symbols['mm_extents'],
                             symbols['mm_extents']+95)
cmd+='exit\n'
path.write_text(s.replace('go 020\nexit\n',cmd,1))
PY
fi

set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s ${PURE_PRESSURE_TIMEOUT_V1614:-180} \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/console.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/console.log" >"$work/console.clean"
if [ "$pure_enabled" = 0 ]; then
    # An opt-in observational negative control, not a PURE feature
    # acceptance. Retain the complete physical guest and tell the
    # caller what the original C source actually reported.
    if grep -q 'PURE[[:space:]]*LOADED' "$work/console.clean"; then
        echo 'FAIL v1631: OFF image loaded PURE MRES unexpectedly' >&2
        keep=1
        exit 1
    fi
    if ! grep -q 'HALT instruction' "$work/console.clean"; then
        echo 'v1631: INCONCLUSIVE physical baseline, guest never HALTed' >&2
        keep=1
        exit 1
    fi
    echo 'v1631: original physical PURE-OFF capacity guest completed'
    echo 'v1631: inspect original guest assertions; no RAM claim made'
    exit 0
fi
if ! grep -q 'PURE[[:space:]]*LOADED' "$work/console.clean"; then
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1614: PURE service was never installed' >&2
    keep=1
    exit 1
fi
if grep -q 'INIT V1' "$work/console.clean"; then
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1614: custom pressure INIT did not execute' >&2
    keep=1
    exit 1
fi
if [ "${PURE_DIAG_HALT_V1615:-0}" = 1 ]; then
    if grep -Eq 'HALT instruction' "$work/console.clean" &&
       grep -Eq '(C[0-7]{6}F|\[A[0-7]{6}/[0-7]{6}\]H)' \
          "$work/console.clean"; then
        echo 'v1615: halted PDP-6 with exact live MM owners; diagnostic only'
        exit 0
    fi
    if grep -Eq 'HALT instruction' "$work/console.clean" &&
       grep -q '<010000+020000>wwww' "$work/console.clean"; then
        echo 'v1615: requester lost during BRK; possible fatal OOM' >&2
        echo 'v1615: post-cleanup MM snapshot is not live refusal geometry' >&2
    fi
    tail -60 "$work/console.clean" >&2
    echo 'v1615: INCONCLUSIVE, no typed refusal or halted BRK snapshot' >&2
    keep=1
    exit 1
fi
text=$(tr -d '\r\n' <"$work/console.clean")
case "$text" in
*'!'*)
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1614: pressure INIT reported a failed assertion' >&2
    keep=1
    exit 1
    ;;
esac
if [ "${PURE_LIFECYCLE_ONLY_V1627:-0}" = 1 ]; then
    case "$text" in
    *'a'*'[B'*'[A'*'L'*'w'*'Z'*'HALT'*) ;;
    *)
        tail -75 "$work/console.clean" >&2
        echo "FAIL v1627: physical ${pure_phys_kwords}K PIPE/WAIT/EXIT incomplete" >&2
        keep=1
        exit 1
        ;;
    esac
    echo "PASS lifecycle: physical ${pure_phys_kwords}K source-checked PIPE/WAIT/EXIT; RAM savings NOT accepted"
    exit 0
fi
case "$text" in
*'a'*'[B'*'[A'*'R'*'w'*'Z'*'HALT'*) ;;
*)
    tail -75 "$work/console.clean" >&2
    echo "FAIL v1614: BRK/RAW/reclaim/wake/WAIT incomplete (sim=$rc)" >&2
    keep=1
    exit 1
    ;;
esac
echo "PASS v1614: physical ${pure_phys_kwords}K TSFS no-AUX PURE BRK reclaim, wake and WAIT"
