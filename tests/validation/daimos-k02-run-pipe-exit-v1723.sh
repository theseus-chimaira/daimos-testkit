#!/bin/sh
# Physical PDP-6: RUN child EXIT retains its last PIPE FD on real MM_BUSY.
# Fault instrumentation is confined to the isolated copied guest kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-run-pipe-exit-v1723.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"

python3 - "$work/source/system/kernel/ipc/pipe.s" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()

def patch(before, after):
    global source
    if source.count(before) != 1:
        raise SystemExit('v1723: physical hook drift: ' + repr(before))
    source = source.replace(before, after, 1)

patch('''pipe_close_free_v870:
        move    1,010
        movei   2,3''', '''pipe_close_free_v870:
        ; Test-only instrumentation for the first final-close object.
        ; Parent RUN inheritance keeps that object alive until child EXIT.
        skipn   daimos_test_target_v1723
        movem   010,daimos_test_target_v1723
        move    4,010
        came    4,daimos_test_target_v1723
        jrst    daimos_test_continue_v1723
        aos     daimos_test_calls_v1723
        ; An actual RUN child, not INIT, must own the final descriptor.
        move    4,proc_current_slot
        caile   4,1
        jrst    daimos_test_child_v1723
        aos     daimos_test_errors_v1723
daimos_test_child_v1723:
        skipn   daimos_test_owner_v1723
        movem   4,daimos_test_owner_v1723
        came    4,daimos_test_owner_v1723
        aos     daimos_test_errors_v1723
        ; FD3 reader has already closed; FD4 writer must remain live
        ; on both attempts. The ordinary FILE/EXIT path is real.
        skipn   file_table
        jrst    daimos_test_no_file_v1723
        move    5,file_table
        skipn   6(5)
        jrst    daimos_test_reader_done_v1723
        aos     daimos_test_errors_v1723
daimos_test_reader_done_v1723:
        move    6,010(5)
        hrrz    6,6
        came    6,010
        aos     daimos_test_errors_v1723
        ; The last writer count must remain uncommitted after a refused
        ; MM release. This is the old reference owner, not a new copy.
        move    6,3(010)
        came    6,[0,,1]
        aos     daimos_test_errors_v1723
        jrst    daimos_test_pin_stage_v1723
daimos_test_no_file_v1723:
        aos     daimos_test_errors_v1723
daimos_test_pin_stage_v1723:
        move    4,daimos_test_calls_v1723
        caie    4,1
        jrst    daimos_test_unpin_stage_v1723
        move    1,010
        pushj   17,mm_pin
        jumpn   1,daimos_test_pin_bad_v1723
        aos     daimos_test_pins_v1723
        jrst    daimos_test_continue_v1723
daimos_test_unpin_stage_v1723:
        caie    4,2
        jrst    daimos_test_counter_bad_v1723
        move    1,010
        pushj   17,mm_unpin
        jumpn   1,daimos_test_pin_bad_v1723
        aos     daimos_test_unpins_v1723
        jrst    daimos_test_continue_v1723
daimos_test_pin_bad_v1723:
        aos     daimos_test_errors_v1723
        jrst    daimos_test_continue_v1723
daimos_test_counter_bad_v1723:
        aos     daimos_test_errors_v1723
daimos_test_continue_v1723:
        move    1,010
        movei   2,3''')

patch('''        pushj   17,mm_free
        jumpe   1,pipe_close_ok''', '''        pushj   17,mm_free
        move    4,010
        came    4,daimos_test_target_v1723
        jrst    daimos_test_free_result_v1723
        camn    1,[-5]
        aos     daimos_test_busy_v1723
        jumpe   1,daimos_test_free_accepted_v1723
        jrst    daimos_test_free_result_v1723
daimos_test_free_accepted_v1723:
        aos     daimos_test_freed_v1723
daimos_test_free_result_v1723:
        jumpe   1,pipe_close_ok''')

source += '''
        .globl mm_pin
        .globl mm_unpin
        .bss
        .globl daimos_test_target_v1723
daimos_test_target_v1723: .block 1
        .globl daimos_test_owner_v1723
daimos_test_owner_v1723: .block 1
        .globl daimos_test_calls_v1723
daimos_test_calls_v1723: .block 1
        .globl daimos_test_pins_v1723
daimos_test_pins_v1723: .block 1
        .globl daimos_test_unpins_v1723
daimos_test_unpins_v1723: .block 1
        .globl daimos_test_busy_v1723
daimos_test_busy_v1723: .block 1
        .globl daimos_test_freed_v1723
daimos_test_freed_v1723: .block 1
        .globl daimos_test_errors_v1723
daimos_test_errors_v1723: .block 1
'''
path.write_text(source)
PY

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=""
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-k02-run-pipe-exit-v1723.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map" || {
    echo 'v1723: guest init not linked at logical 020' >&2
    exit 1
}

build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -70 "$work/build.log" >&2
        echo 'v1723: isolated PDP-6 image build failed' >&2
        exit 1
    }

for name in target owner calls pins unpins busy freed errors; do
    sym="daimos_test_${name}_v1723"
    addr=$(awk -v s="$sym" '$1 == s {print $2; exit}' "$build/kcore.map")
    test -n "$addr" || { echo "v1723: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' \
    -e '/^exit$/d' "$build/boot.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$build/boot.ini"
done < "$work/addresses"
printf 'exit\n' >> "$build/boot.ini"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 75s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/simh.out" >&2
    echo "v1723: physical guest exit $rc" >&2
    exit 1
fi

python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys

out = Path(sys.argv[2]).read_text(errors='replace')
seen = {}
for row in Path(sys.argv[1]).read_text().splitlines():
    name, addr = row.split()
    values = re.findall(r'(?im)^\s*0*' + re.escape(addr.lstrip('0')) +
                        r'\s*:\s*([0-7]+)\b', out)
    if not values:
        raise SystemExit('v1723: missing physical diagnostic: ' + name +
                         '\n' + out[-1500:])
    seen[name] = int(values[-1], 8)
expected = dict(calls=2, pins=1, unpins=1, busy=1, freed=1, errors=0)
for name, value in expected.items():
    if seen.get(name) != value:
        raise SystemExit('v1723: ' + name + ': ' + str(seen.get(name)) +
                         ' expected ' + str(value) + '\n' + out[-1750:])
if seen['owner'] <= 1 or seen['target'] == 0:
    raise SystemExit('v1723: final PIPE MM owner is not a RUN child')
if re.search(r'(?m)^P\r?$', out) is None or 'HALT' not in out or '!' in out:
    raise SystemExit('v1723: parent WAIT/guest completion failed\n' +
                     out[-1600:])
print('v1723: 256K PDP-6 RUN child final PIPE EXIT, real MM pin/BUSY, '
      'retained FD, retry EXIT and parent WAIT PASS:', seen)
PY
