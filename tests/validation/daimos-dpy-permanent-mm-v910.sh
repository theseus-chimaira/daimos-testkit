#!/bin/sh
# Full PDP-6 permanent physical-MM refusal across three DPY CLOSE attempts.
# All fault injection and counters exist only in a disposable kernel copy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dpy-permanent-mm-v910.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
printf 'v910: work directory %s\n' "$work"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/mm/mm_pdp6.s" \
    "$work/source/system/kernel/drivers/dpy_io.s" <<'PY'
from pathlib import Path
import sys
mm=Path(sys.argv[1]); dp=Path(sys.argv[2]); source=mm.read_text()
def patch(old,new):
    global source
    if source.count(old)!=1:
        raise SystemExit('v910: MM injection anchor not unique: '+repr(old))
    source=source.replace(old,new,1)
patch('''mm_free:
        move    5,1
        move    6,2
        move    7,3''','''mm_free:
        caie    3,014                 ; DPY raw-list MM owner only
        jrst    mm_free_original_v910
        caie    2,3                   ; MM_TYPE_KERNEL_DYNAMIC only
        jrst    mm_free_original_v910
        skipn   daimos_test_target_v910
        movem   1,daimos_test_target_v910
        move    4,daimos_test_target_v910
        came    4,1
        jrst    mm_free_original_v910
        aos     daimos_test_calls_v910
        move    4,daimos_test_calls_v910
        caie    4,1
        jrst    daimos_test_unpin_v910
        pushj   17,mm_pin            ; pin exact real MM extent
        jumpe   1,daimos_test_pin_ok_v910
        aos     daimos_test_errors_v910
        jrst    mm_free_restore_v910
daimos_test_pin_ok_v910:
        aos     daimos_test_pins_v910
        jrst    mm_free_restore_v910
daimos_test_unpin_v910:
        ; Permanent provider refusal: retain the real MM pin.
        ; Repeated CLOSE must never force-release the owned extent.
mm_free_restore_v910:
        move    1,daimos_test_target_v910
        movei   2,3
        movei   3,014
mm_free_original_v910:
        move    5,1
        move    6,2
        move    7,3''')
patch('''mm_free_busy:
        movni   1,5''','''mm_free_busy:
        move    4,daimos_test_target_v910
        camn    4,5
        aos     daimos_test_busy_v910
        movni   1,5''')
source+='''
        .globl mm_pin
        .globl mm_unpin
        .bss
        .globl daimos_test_target_v910
daimos_test_target_v910: .block 1
        .globl daimos_test_calls_v910
daimos_test_calls_v910: .block 1
        .globl daimos_test_pins_v910
daimos_test_pins_v910: .block 1
        .globl daimos_test_unpins_v910
daimos_test_unpins_v910: .block 1
        .globl daimos_test_busy_v910
daimos_test_busy_v910: .block 1
        .globl daimos_test_errors_v910
daimos_test_errors_v910: .block 1
        .globl daimos_test_refresh_v910
daimos_test_refresh_v910: .block 1
        .globl daimos_test_raw_pi_v910
daimos_test_raw_pi_v910: .block 1
        .globl daimos_test_after_busy_v910
daimos_test_after_busy_v910: .block 1
'''
mm.write_text(source)
source=dp.read_text()
old='''        skipn dpy_list_base
        jrst dpy_pi_retained_done
        setzm dpy_refresh_iowd'''
new='''        skipn dpy_list_base
        jrst dpy_pi_retained_done
        aos daimos_test_raw_pi_v910
        setzm dpy_refresh_iowd'''
if source.count(old)!=1:
    raise SystemExit('v910: raw PI7 hook anchor not unique')
source=source.replace(old,new,1)
old='''        skipn dpy_list_base
        jrst dpy_refresh_retained
        move 1,dpy_list_iowd'''
new='''        skipn dpy_list_base
        jrst dpy_refresh_retained
        aos daimos_test_refresh_v910
        ; Count raw frames replayed after MM_BUSY while still pinned.
        skipn daimos_test_busy_v910
        jrst daimos_test_refresh_next_v910
        skipe daimos_test_unpins_v910
        jrst daimos_test_refresh_next_v910
        aos daimos_test_after_busy_v910
daimos_test_refresh_next_v910:
        move 1,dpy_list_iowd'''
if source.count(old)!=1:
    raise SystemExit('v910: raw PI6 hook anchor not unique')
source=source.replace(old,new,1)
source+='''
        .globl daimos_test_raw_pi_v910
        .globl daimos_test_refresh_v910
        .globl daimos_test_busy_v910
        .globl daimos_test_unpins_v910
        .globl daimos_test_after_busy_v910
'''
dp.write_text(source)
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
    -S "$self/daimos-dpy-permanent-mm-v910.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
build="$work/build/system/boot/pdp6"
printf 'v910: building a disposable 256K PDP-6 image with DPY enabled\n'
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -90 "$work/build.log" >&2
        echo 'v910: isolated image build failed' >&2
        exit 1
    }
for name in target calls pins unpins busy errors refresh raw_pi after_busy; do
    sym="daimos_test_${name}_v910"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v910: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' \
    "$build/boot.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$build/boot.ini"
done < "$work/addresses"
printf 'exit\n' >> "$build/boot.ini"
printf 'v910: booting guest and checking physical DPY refresh/PI7 state\n'
set +e
(cd "$build"; TERM=dumb timeout -k 2s 90s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/simh.out" >&2
    echo "v910: simulator exited $rc" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys
out=Path(sys.argv[2]).read_text(errors='replace')
seen={}
for line in Path(sys.argv[1]).read_text().splitlines():
    name,addr=line.split()
    values=re.findall(r'(?im)^\s*0*'+re.escape(addr.lstrip('0'))+
                      r'\s*:\s*([0-7]+)\b',out)
    if not values:
        raise SystemExit('v910: missing sample '+name+'\n'+out[-2000:])
    seen[name]=int(values[-1],8)
for name,value in dict(pins=1,unpins=0,busy=3,errors=0).items():
    if seen[name]!=value:
        raise SystemExit('v910: '+name+'='+str(seen[name])+
                         ' expected '+str(value)+'\n'+out[-2400:])
if seen['calls'] != 3 or not seen['target'] or \
        seen['refresh'] < 3 or seen['raw_pi'] < 3 or \
        seen['after_busy'] < 1 or \
        '<' not in out or 'D' not in out or \
        'HALT' not in out or '!' in out:
    raise SystemExit('v910: guest or raw PI7 did not complete\n'+
                     str(seen)+'\n'+out[-2400:])
print('v910: booted PDP-6 DPY raw PI6/PI7 physical-MM permanent MM_BUSY retention PASS:',seen)
PY
