#!/bin/sh
# Full-system PDP-6: actual MM_BUSY on EXIT, with a disposable kernel overlay.
set -eu
: "$DAIMOS_REPO" "$PDP10_PREFIX"
if [ -z "$DAIMOS_REPO" ] || [ -z "$PDP10_PREFIX" ]; then exit 2; fi
TMPDIR=${TMPDIR:-$HOME/tmp}
KEEP_TEST=${KEEP_TEST:-0}
export TMPDIR
mkdir -p "$TMPDIR"
tag=daimos-uarea-pin-integration-v882
mode=${DAIMOS_UAREA_TEST_MODE:-current}
case "$mode" in
current|noncurrent) ;;
*) echo "$tag: invalid fault-injection mode $mode" >&2; exit 2 ;;
esac
work=$(mktemp -d "$TMPDIR/$tag.XXXXXX")
cleanup() { if [ "$KEEP_TEST" != 1 ]; then rm -rf "$work"; fi; }
trap cleanup EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/proc_pdp6.s" <<'PY'
from pathlib import Path
import os
import sys
p = Path(sys.argv[1])
s = p.read_text()
if os.environ.get('DAIMOS_UAREA_TEST_MODE', 'current') == 'noncurrent':
    needle = """proc_event_fatal_other:
        hlrz    1,(012)"""
    assert s.count(needle) == 1
    s = s.replace(needle, """proc_event_fatal_other:
        ; v883 disposable test: select the first noncurrent fatal owner.
        setom   daimos_test_noncurrent_seen_v883
        skipn   daimos_test_exit_slot_v882
        movem   010,daimos_test_exit_slot_v882
        hlrz    1,(012)""")
needle = """        push    17,10
        move    10,2
        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE"""
assert s.count(needle) == 1
replacement = """        push    17,10
        move    10,2
        ; v882 temporary test hook: preserve arguments across real MM calls.
        push    17,1
        push    17,2
        push    17,4
        ; Only an EXIT initiated by its own process can hand off to slot 0.
        move    5,daimos_test_exit_slot_v882
        jumpe   5,daimos_test_done_v882
        came    1,5
        jrst    daimos_test_done_v882
        skipn   daimos_test_target_v882
        movem   1,daimos_test_target_v882
        came    1,daimos_test_target_v882
        jrst    daimos_test_done_v882
        aos     daimos_test_calls_v882
        move    5,daimos_test_calls_v882
        caie    5,1
        jrst    daimos_test_maybe_unpin_v882
        move    1,(17)
        pushj   17,mm_pin
        jumpn   1,daimos_test_pin_error_exit_v882
        aos     daimos_test_pins_v882
        jrst    daimos_test_done_v882
daimos_test_maybe_unpin_v882:
        caie    5,3
        jrst    daimos_test_done_v882
        move    1,(17)
        pushj   17,mm_unpin
        jumpn   1,daimos_test_pin_error_exit_v882
        aos     daimos_test_unpins_v882
        jrst    daimos_test_done_v882
daimos_test_pin_error_exit_v882:
        setom   daimos_test_error_v882
daimos_test_done_v882:
        pop     17,4
        pop     17,2
        pop     17,1
        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE"""
s = s.replace(needle, replacement)
needle = """        pushj   17,mm_free
        jumpn   1,proc_uarea_release_fail"""
assert s.count(needle) == 1
s = s.replace(needle, """        pushj   17,mm_free
        camn    1,[-5]                 ; true MM_ERR_BUSY, extent pinned
        aos     daimos_test_busy_v882
        jumpn   1,proc_uarea_release_fail""")
s += """
        .bss
        .globl daimos_test_noncurrent_seen_v883
daimos_test_noncurrent_seen_v883: .block 1
        .globl daimos_test_exit_slot_v882
daimos_test_exit_slot_v882: .block 1
        .globl daimos_test_target_v882
daimos_test_target_v882: .block 1
        .globl daimos_test_calls_v882
daimos_test_calls_v882: .block 1
        .globl daimos_test_pins_v882
daimos_test_pins_v882: .block 1
        .globl daimos_test_unpins_v882
daimos_test_unpins_v882: .block 1
        .globl daimos_test_busy_v882
daimos_test_busy_v882: .block 1
        .globl daimos_test_error_v882
daimos_test_error_v882: .block 1
"""
p.write_text(s)
q = p.with_name('proc.c')
t = q.read_text()
needle = '        slot = (unsigned int)proc_current_slot;\n        proc_current_slot = 0UL;'
assert t.count(needle) == 1
t = t.replace(needle,
    '        slot = (unsigned int)proc_current_slot;\n'
    '        if (daimos_test_exit_slot_v882 == 0UL)\n'
    '                daimos_test_exit_slot_v882 = (kword_t)slot;\n'
    '        proc_current_slot = 0UL;')
needle = 'int\nproc_exit_finish(int status)\n'
assert t.count(needle) == 1
t = t.replace(needle,
    'extern kword_t daimos_test_exit_slot_v882;\n' + needle)
q.write_text(t)
PY

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
inc=""
for d in boot core drivers fs ipc mm modules proc storage; do
    inc="$inc -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
"$cc" -std=c99 -Os $inc -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-session-teardown-v1.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"

build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" \
    SIMH_DPY_MODE=HEADLESS > "$work/build.log" 2>&1 || {
        tail -55 "$work/build.log" >&2
        echo "$tag: isolated build failed" >&2
        exit 1
    }

map="$build/kcore.map"
for sym in daimos_test_noncurrent_seen_v883 daimos_test_exit_slot_v882 daimos_test_target_v882 daimos_test_calls_v882 \
    daimos_test_pins_v882 daimos_test_unpins_v882 \
    daimos_test_busy_v882 daimos_test_error_v882; do
    address=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
    test -n "$address" || { echo "$tag: no symbol $sym" >&2; exit 1; }
    printf '%s %s\n' "$sym" "$address" >> "$work/addresses"
done
boot="$build/boot.ini"
sed -i \
    -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' \
    -e '/^exit$/d' "$boot"
while read -r symbol address; do
    printf 'examine %s\n' "$address" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"

set +e
(cd "$build"; TERM=dumb timeout -k 2s 50s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -75 "$work/simh.out" >&2
    echo "$tag: SIMH exit code $rc" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" <<'PY'
import re
import os
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
output = Path(sys.argv[2]).read_text(errors='replace')
if '<' not in output or '!' in output or 'HALT' not in output:
    raise SystemExit('v882: CTY/sentinel/final HALT failed: ' + output[-650:])
seen = {}
for line in lines:
    name, address = line.split()
    match = re.findall(
        r'(?im)^\s*0*' + re.escape(address.lstrip('0')) +
        r'\s*:\s*([0-7]+)\b', output)
    if not match:
        raise SystemExit('v882: missing SIMH memory sample: ' + name + ' ' +
                         address + '\n' + output[-1200:])
    seen[name] = int(match[-1], 8)
print('v882 actual MM pin/unpin counters: ' + str(seen))
expect = {
    'daimos_test_calls_v882': 3,
    'daimos_test_pins_v882': 1,
    'daimos_test_unpins_v882': 1,
    'daimos_test_busy_v882': 2,
    'daimos_test_error_v882': 0
}
if seen['daimos_test_target_v882'] < 1:
    raise SystemExit('v882: no u-area selected')
if seen['daimos_test_exit_slot_v882'] != seen['daimos_test_target_v882']:
    raise SystemExit('v882: unstable EXIT-owner selection')
if os.environ.get('DAIMOS_UAREA_TEST_MODE', 'current') == 'noncurrent' and not seen['daimos_test_noncurrent_seen_v883']:
    raise SystemExit('v883: no non-current fatal delivery instrumented')
for name, value in expect.items():
    if seen[name] != value:
        raise SystemExit('v882: FAIL: ' + name + ' (' + str(seen[name]) +
                         ', expected ' + str(value) + ')')
print('full-system real MM_BUSY, deferred tick retry, final free and session HUP/TTY PASS')
PY
