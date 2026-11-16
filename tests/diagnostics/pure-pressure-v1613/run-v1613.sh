#!/bin/sh
# Experimental (currently failing) physical PDP-6 no-AUXST1 pressure/WAIT
# diagnostic. It keeps test media and exact guest logs for analysis.
# The original disk-swap pipe workload requests a new *large process*
# before it can validate RAW prefix reclaim, and the third child RUN
# is refused on the tested 64K arena. NOT a passing acceptance test.
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
work=$(mktemp -d "$TMPDIR/pure-pressure-v1613.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1613: pressure guest evidence $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/user"
source="$testkit/tests/validation/daimos-swap-wait-v1.c"

python3 - "$source" "$work/user/init-v1613.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
def update(a, b):
    global s
    assert s.count(a) == 1, 'pressure test source changed: ' + a
    s = s.replace(a, b)

# With 64K rather than the original 32K, grow the user image, but
# keep at least one physical extent available for a successful RUN.
# v1613's first 020000-word attempt could not admit pressure child C.
update('pressure_area[010400]', 'pressure_area[016000]')
update('pressure_area[010377]',
       'pressure_area[(sizeof pressure_area / sizeof pressure_area[0]) - 1U]')
# An absent AUXST1 must remain swapless throughout the guest workload.
update('''        if (dsys_storagectl(SYS_STORAGECTL_SWAP) != 0)
                fail('s', 010);
''', '''        /* PURE MRES was installed by KINIT, no DISK storagectl. */
''')
# DISK frees the entire image; RAW PURE frees only immutable text.
# Test that a full 0200-word text sector actually left physical MM.
update('''all_resident >= mem.process_words + b.words''',
       '''all_resident >= mem.process_words + 0200UL''')
# The metrics are obtained from the actual in-guest MEMINFO syscall,
# without changing allocator/scheduler code or injecting a kernel hook.
needle = '''static int
reader_swap_pressure_active('''
stats = '''static void
stamp_ram_v1613(int tag)
{
        struct sys_meminfo m;
        unsigned int i;

        if (dsys_meminfo(&m) != 0)
                return;
        (void)mark('[');
        (void)mark(tag);
        for (i = 0U; i < 6U; ++i)
                (void)mark('0' + (int)((m.process_words >>
                    (3U * (5U - i))) & 07UL));
        (void)mark('/');
        for (i = 0U; i < 6U; ++i)
                (void)mark('0' + (int)((m.resident_words >>
                    (3U * (5U - i))) & 07UL));
        (void)mark(']');
}

'''
update(needle, stats + needle)
update('''        if (mark('a') != 0)
                fail('4', 014);''',
       '''        if (mark('a') != 0)
                fail('4', 014);
        stamp_ram_v1613('a');''')
update('''        if (mark('b') != 0)
                fail('7', 017);''',
       '''        if (mark('b') != 0)
                fail('7', 017);
        stamp_ram_v1613('b');''')
update('''        pressure_c = spawn_child(PRESSURE_MODE, gate_r);''',
       '''        stamp_ram_v1613('c');
        pressure_c = spawn_child(PRESSURE_MODE, gate_r);''')
Path(sys.argv[2]).write_text(s)
PY

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -S "$work/user/init-v1613.c" \
    -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
"$das" -C -F -O "$work/user/crt0.dobj" \
    "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" \
    -M "$work/user/init.map" "$work/user/crt0.dobj" \
    "$work/user/syscall.dobj" "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"

boot="$work/build"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$boot" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED=1 \
    SYSTEM_INIT_DXR="$work/user/init.dxr" >"$work/build.log" 2>&1 || {
    tail -60 "$work/build.log" >&2
    keep=1
    exit 1
}
grep -F "F /SYSTEM/INIT $work/user/init.dxr " \
    "$boot/tsfs-root.manifest" >/dev/null
grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"

awk '!/^attach -q (dsk[0-9]+|dr[0-9]+) /' \
    "$boot/boot.ini" >"$work/noaux.ini"
if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' "$work/noaux.ini"; then
    echo 'FAIL v1613: pressure guest still has auxiliary media' >&2
    exit 1
fi
port=$((32000 + ($$ % 15000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/headless.ini" "$port" "$((port+14000))"

set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s ${PURE_PRESSURE_TIMEOUT_V1613:-180} \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/console.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/console.log" >"$work/console.clean"
if ! grep -q 'PURE[[:space:]]*LOADED' "$work/console.clean"; then
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1613: PURE service was never installed' >&2
    keep=1
    exit 1
fi
if grep -q 'INIT V1' "$work/console.clean"; then
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1613: custom pressure INIT did not execute' >&2
    keep=1
    exit 1
fi
text=$(tr -d '\r\n' <"$work/console.clean")
case "$text" in
*'!'*)
    tail -75 "$work/console.clean" >&2
    echo 'FAIL v1613: pressure INIT reported a failed assertion' >&2
    keep=1
    exit 1
    ;;
esac
case "$text" in
*'r'*'a'*'p'*'b'*'S'*'W'*'P'*'HALT'*) ;;
*)
    tail -75 "$work/console.clean" >&2
    echo "FAIL v1613: pressure/reclaim/wake/WAIT incomplete (sim=$rc)" >&2
    keep=1
    exit 1
    ;;
esac
echo 'PASS v1613: physical 64K TSFS no-AUX PURE reclaim, wake and WAIT'
