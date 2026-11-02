#!/bin/sh
# v917 full-system PDP-6: permanent invalid FILE refusal, safe owner, live bystander.
# Production sources are NEVER modified; all probes live in a copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-provider-foreign-live-v917.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
def patch(rel,old,new):
    p=root/rel; s=p.read_text()
    if s.count(old)!=1:
        raise SystemExit('v917: nonunique hook '+rel+': '+str(s.count(old)))
    p.write_text(s.replace(old,new,1))
patch('fs/fs_mres.s',
      'fs_provider_unlock:\n        push    17,1',
      '''fs_provider_unlock:
        move    4,proc_current_slot
        caie    4,2
        jrst    v917_normal_unlock
        aos     daimos_test_owner_stalled_v917
v917_owner_halted:
        ; Hold the real provider lease while yielding to the clock.
        ; Unlike a tight executive loop, this lets unrelated users run.
        movei   1,020
        pushj   17,proc_sleep_ticks
        jumpn   1,v917_owner_sleep_bad
        jrst    v917_owner_halted
v917_owner_sleep_bad:
        setom   daimos_test_errors_v917
        jrst    v917_owner_halted
v917_normal_unlock:
        push    17,1''')
patch('fs/fs_mres.s',
      'fs_provider_lock_sleep_v915:\n        movei   1,fs_provider_wait_event_v917',
      '''fs_provider_lock_sleep_v915:
        move    4,proc_current_slot
        caie    4,3
        jrst    v917_other_wait
        aos     daimos_test_waiters_v917
        hlrz    4,fs_provider_ready
        caie    4,3
        setom   daimos_test_errors_v917
v917_other_wait:
        movei   1,fs_provider_wait_event_v917''')
p=root/'fs/fs_mres.s'
p.write_text(p.read_text()+'''
        .bss
        .globl daimos_test_owner_stalled_v917
daimos_test_owner_stalled_v917: .block 1
        .globl daimos_test_waiters_v917
daimos_test_waiters_v917: .block 1
        .globl daimos_test_errors_v917
daimos_test_errors_v917: .block 1
        .globl daimos_test_never_wake_v917
daimos_test_never_wake_v917: .block 1
''')
patch('proc/proc_pdp6.s',
      'proc_exit_current:\n        move    3,1',
      '''proc_exit_current:
        move    4,proc_current_slot
        caie    4,1
        jrst    v917_normal_exit
        halt
        jrst    .-1
v917_normal_exit:
        move    3,1''')
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
"$cc" -std=c89 -Os $inc -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-provider-foreign-live-v917.c" -o "$work/user/init.s"
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
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -55 "$work/build.log" >&2
        echo "v917: isolated kernel/image build failed: $work" >&2
        exit 1
    }
map="$build/kcore.map"
for name in owner_stalled waiters errors; do
    symbol="daimos_test_${name}_v917"
    addr=$(awk -v s="$symbol" '$1 == s {print $2}' "$map")
    test -n "$addr" || { echo "v917: no $symbol" >&2; exit 1; }
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
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/simh.out" >&2
    echo "v917: SIMH failed ($rc): $work" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys
names = Path(sys.argv[1]).read_text().splitlines()
output = Path(sys.argv[2]).read_text(errors='replace')
counts = {}
for line in names:
    name, address = line.split()
    matches = re.findall(r'(?im)^\s*0*' +
                         re.escape(address.lstrip('0')) +
                         r'\s*:\s*([0-7]+)\b', output)
    if not matches:
        raise SystemExit('v917 missing SIMH sample ' + name +
                         ': ' + output[-1600:])
    counts[name] = int(matches[-1], 8)
print('v917 booted provider lease counters:', counts)
if counts['owner_stalled'] != 1 or counts['waiters'] < 1 or counts['errors'] != 0:
    raise SystemExit('v917: invalid lock owner/wait state: '+str(counts))
if 'HALT' not in output or '<' not in output or 'O' not in output or \
        'W' not in output or 'P' not in output or \
        output.count('S') < 5 or '!' in output:
    raise SystemExit('v917: missing independent progress: '+output[-950:])
print('v917: booted foreign provider lock wait, independent progress PASS')
PY
