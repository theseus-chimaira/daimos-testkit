#!/bin/sh
# Full PDP-6 guest: real MM_BUSY before unpublished RUN VM destruction.
# Fault injection exists only in a copied kernel; DAIMOS stays unmodified.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-run-prevm-uarea-v895.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"

python3 - "$work/source/system/kernel/proc/proc_pdp6.s" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
def patch(old, new):
    global source
    if source.count(old) != 1:
        raise SystemExit('v895: invalid isolated hook: ' + repr(old))
    source = source.replace(old, new)

# Pin the rejected RUN child BEFORE the real process-VM destructor.
# The first two VM frees must return the real allocator's MM_ERR_BUSY;
# the slot-zero reaper unpins before its second (third overall) attempt.
patch('proc_discard_vm_retry_v894:\n        move    1,10',
      '''proc_discard_vm_retry_v894:
        move    4,11
        caie    4,3
        jrst    daimos_test_vm_continue_v895
        skipn   daimos_test_target_v895
        movem   11,daimos_test_target_v895
        aos     daimos_test_calls_v895
        move    4,daimos_test_calls_v895
        caie    4,1
        jrst    daimos_test_maybe_unpin_v895
        hrrz    1,1(10)              ; actual process VM physical base
        pushj   17,mm_pin
        jumpe   1,daimos_test_pinned_v895
        setom   daimos_test_error_v895
        jrst    daimos_test_vm_continue_v895
daimos_test_pinned_v895:
        aos     daimos_test_pins_v895
        jrst    daimos_test_vm_continue_v895
daimos_test_maybe_unpin_v895:
        caie    4,3
        jrst    daimos_test_vm_continue_v895
        hrrz    1,1(10)
        pushj   17,mm_unpin
        jumpe   1,daimos_test_unpinned_v895
        setom   daimos_test_error_v895
        jrst    daimos_test_vm_continue_v895
daimos_test_unpinned_v895:
        aos     daimos_test_unpins_v895
daimos_test_vm_continue_v895:
        move    1,10''')

# Real MM free inside the genuine VM destructor; no fabricated errno.
q = path.with_name('vm_pdp6.s')
qsource = q.read_text()
needle = '        pushj   17,mm_free\n        jumpn   1,vm_space_destroy_fail'
if qsource.count(needle) != 1:
    raise SystemExit('v895: VM free hook is not unique')
q.write_text(qsource.replace(needle, '''        pushj   17,mm_free
        camn    1,[-5]
        aos     daimos_test_busy_v895
        jumpn   1,vm_space_destroy_fail'''))

# Count only maintenance retries for pending pre-VM RUN descriptors.
patch('        move    1,10\n        pushj   17,proc_slot_discard\n        jrst    proc_finish_service_result_v892',
      '''        aos     daimos_test_reaper_v895
        move    1,10
        pushj   17,proc_slot_discard
        jrst    proc_finish_service_result_v892''')

source += '''
        .bss
        .globl daimos_test_target_v895
daimos_test_target_v895: .block 1
        .globl daimos_test_pins_v895
daimos_test_pins_v895: .block 1
        .globl daimos_test_unpins_v895
daimos_test_unpins_v895: .block 1
        .globl daimos_test_calls_v895
daimos_test_calls_v895: .block 1
        .globl daimos_test_busy_v895
daimos_test_busy_v895: .block 1
        .globl daimos_test_reaper_v895
daimos_test_reaper_v895: .block 1
        .globl daimos_test_error_v895
daimos_test_error_v895: .block 1
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
"$cc" -std=c99 -Os $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-run-prevm-uarea-v895.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"

build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" \
    "${MAKE:-make}" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -60 "$work/build.log" >&2
        echo 'v895: isolated build failed' >&2
        exit 1
    }

for name in target pins unpins calls busy reaper error; do
    sym="daimos_test_${name}_v895"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v895: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 75s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/simh.out" >&2
    echo "v895: PDP-6 simulator exited $rc" >&2
    exit 1
fi

python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys

output = Path(sys.argv[2]).read_text(errors='replace')
seen = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, address = line.split()
    values = re.findall(r'(?im)^\s*0*' +
                        re.escape(address.lstrip('0')) +
                        r'\s*:\s*([0-7]+)\b', output)
    if not values:
        raise SystemExit('v895: missing sample ' + name + '\n' + output[-1500:])
    seen[name] = int(values[-1], 8)
expected = dict(pins=1, unpins=1, calls=3, busy=2, reaper=2, error=0)
for name, value in expected.items():
    if seen[name] != value:
        raise SystemExit('v895: ' + name + '=' + str(seen[name]) +
                         ' expected ' + str(value) + '\n' + output[-1600:])
if seen['target'] <= 2 or 'HALT' not in output or '!' in output or \
        '<' not in output or 'R' not in output or 'B' not in output or \
        'F' not in output or 'P' not in output:
    raise SystemExit('v895: RUN/WAIT/bystander markers failed\n' +
                     output[-1600:])
print('v895: full PDP-6 RUN rollback, real MM pin/busy/unpin, '
      'deferred FREE, no child WAIT, bystander PASS:', seen)
PY
