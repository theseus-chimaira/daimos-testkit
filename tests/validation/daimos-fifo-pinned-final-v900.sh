#!/bin/sh
# Full PDP-6: pinned named FIFO must be relinked after final MM refusal.
# Test-only MM injection is confined to an isolated copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fifo-pinned-final-v900.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/ipc/pipe.s" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
needle='''pipe_close_free_v870:
        move    1,010
        movei   2,3'''
assert s.count(needle)==1
hook='''pipe_close_free_v870:
        ; Test-only, record the first genuinely last-reference object.
        skipn   daimos_test_target_v900
        movem   010,daimos_test_target_v900
        move    4,010
        came    4,daimos_test_target_v900
        jrst    daimos_test_free_continue_v900
        aos     daimos_test_calls_v900
        move    4,daimos_test_calls_v900
        caie    4,1
        jrst    daimos_test_maybe_unpin_v900
        move    1,010
        pushj   17,mm_pin
        jumpn   1,daimos_test_pin_error_v900
        aos     daimos_test_pins_v900
        jrst    daimos_test_free_continue_v900
daimos_test_pin_error_v900:
        aos     daimos_test_errors_v900
        jrst    daimos_test_free_continue_v900
daimos_test_maybe_unpin_v900:
        caie    4,2
        jrst    daimos_test_free_continue_v900
        move    1,010
        pushj   17,mm_unpin
        jumpn   1,daimos_test_pin_error_v900
        aos     daimos_test_unpins_v900
daimos_test_free_continue_v900:
        move    1,010
        movei   2,3'''
s=s.replace(needle,hook)
needle2='''        pushj   17,mm_free
        jumpe   1,pipe_close_ok'''
assert s.count(needle2)==1
s=s.replace(needle2,'''        pushj   17,mm_free
        camn    1,[-5]
        aos     daimos_test_busy_v900
        jumpe   1,pipe_close_ok''')
s+='''
        .globl mm_pin
        .globl mm_unpin
        .bss
        .globl daimos_test_target_v900
daimos_test_target_v900: .block 1
        .globl daimos_test_calls_v900
daimos_test_calls_v900: .block 1
        .globl daimos_test_pins_v900
daimos_test_pins_v900: .block 1
        .globl daimos_test_unpins_v900
daimos_test_unpins_v900: .block 1
        .globl daimos_test_busy_v900
daimos_test_busy_v900: .block 1
        .globl daimos_test_errors_v900
daimos_test_errors_v900: .block 1
'''
p.write_text(s)
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
    -S "$self/daimos-fifo-pinned-final-v900.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -60 "$work/build.log" >&2
        exit 1
    }
for name in target calls pins unpins busy errors; do
    sym="daimos_test_${name}_v900"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v900: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' \
    "$build/boot.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$build/boot.ini"
done < "$work/addresses"
printf 'exit\n' >> "$build/boot.ini"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 75s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -75 "$work/simh.out" >&2
    echo "v900: simulator exited $rc" >&2; exit 1
fi
python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys
out=Path(sys.argv[2]).read_text(errors='replace')
seen={}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr=line.split()
    values=re.findall(r'(?im)^\s*0*'+re.escape(addr.lstrip('0'))+
                      r'\s*:\s*([0-7]+)\b',out)
    if not values:
        raise SystemExit('v900: missing '+name+'\n'+out[-1300:])
    seen[name]=int(values[-1],8)
if seen['calls'] < 2:
    raise SystemExit('v900: fewer than two final-close attempts')
# A new pipe may reuse the physical base and increment calls again.
for name,value in dict(pins=1,unpins=1,busy=1,errors=0).items():
    if seen[name]!=value:
        raise SystemExit('v900: '+name+' '+str(seen[name])+
                         ' expected '+str(value)+'\n'+out[-1400:])
if not seen['target'] or '<' not in out or 'F' not in out or \
        'HALT' not in out or '!' in out:
    raise SystemExit('v900: guest failed\n'+out[-1600:])
print('v900: full PDP-6 real MM pinned FIFO final close, relinked stream, shared reopen, retry PASS:',seen)
PY
