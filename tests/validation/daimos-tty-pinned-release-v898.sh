#!/bin/sh
# Full PDP-6: real physical MM pin refuses TTY detach; unpin retries.
# Test-only MM injection is confined to an isolated copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tty-pinned-release-v898.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/proc.c" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
needle='''        proc_tty_line_reset(tty);
        return proc_tty_line_base_get(tty) == 0UL ? 0 : -1;
}'''
assert s.count(needle)==1
replacement='''        if (tty == 0U) {
                ++daimos_test_calls_v898;
                if (daimos_test_calls_v898 == 2UL) {
                        kword_t base;
                        base = 0UL;
                        if (mm_alloc(PROC_TTY_LINE_WORDS,
                            MM_TYPE_KERNEL_DYNAMIC,
                            PROC_TTY_LINE_MM_OWNER_BASE, MM_ALLOC_LOW,
                            &base) != MM_OK || base == 0UL) {
                                ++daimos_test_errors_v898;
                        } else {
                                daimos_test_base_v898 = base;
                                proc_tty_line_base_set(0U, base);
                                if (mm_pin(base) != MM_OK)
                                        ++daimos_test_errors_v898;
                                else
                                        ++daimos_test_pins_v898;
                        }
                } else if (daimos_test_calls_v898 == 3UL) {
                        if (mm_unpin(daimos_test_base_v898) != MM_OK)
                                ++daimos_test_errors_v898;
                        else
                                ++daimos_test_unpins_v898;
                }
        }
        proc_tty_line_reset(tty);
        if (tty == 0U && daimos_test_calls_v898 == 2UL &&
            proc_tty_line_base_get(tty) != 0UL)
                ++daimos_test_busy_v898;
        return proc_tty_line_base_get(tty) == 0UL ? 0 : -1;
}'''
assert s.count(needle)==1
insert='''kword_t daimos_test_calls_v898;
kword_t daimos_test_base_v898;
kword_t daimos_test_pins_v898;
kword_t daimos_test_unpins_v898;
kword_t daimos_test_busy_v898;
kword_t daimos_test_errors_v898;

'''
needle2='''int
proc_tty_line_try_reset_v897(unsigned int tty)
{'''
assert s.count(needle2)==1
s=s.replace(needle2,insert+needle2)
s=s.replace(needle,replacement)
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
    -S "$self/daimos-tty-pinned-release-v898.c" -o "$work/user/init.s"
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
for name in calls base pins unpins busy errors; do
    sym="daimos_test_${name}_v898"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v898: missing $sym" >&2; exit 1; }
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
    echo "v898: simulator exited $rc" >&2; exit 1
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
        raise SystemExit('v898: missing '+name+'\n'+out[-1300:])
    seen[name]=int(values[-1],8)
for name,value in dict(calls=4,pins=1,unpins=1,busy=1,errors=0).items():
    if seen[name]!=value:
        raise SystemExit('v898: '+name+' '+str(seen[name])+
                         ' expected '+str(value)+'\n'+out[-1400:])
if not seen['base'] or '<' not in out or 'H' not in out or \
        'HALT' not in out or '!' in out:
    raise SystemExit('v898: guest failed\n'+out[-1600:])
print('v898: full PDP-6 real MM pin/busy/unpin, failed TTY detach '
      'retains owner, retry/attach and child PASS:',seen)
PY
