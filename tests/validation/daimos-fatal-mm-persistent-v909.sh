#!/bin/sh
# v909 full-system PDP-6: permanent u-area MM pin, safe owner, live bystander.
# Production sources are NEVER modified; all probes live in a copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
if [ "${DAIMOS_V1101_MM_MODE:-pin}" = wrong-owner ]; then
    test_name=daimos-fatal-mm-wrong-owner-v1101
else
    test_name=daimos-fatal-mm-persistent-v909
fi
work=$(mktemp -d "$TMPDIR/$test_name.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel" "${DAIMOS_V1101_MM_MODE:-pin}" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
mode = sys.argv[2]
if mode not in ('pin', 'wrong-owner'):
    raise SystemExit('v909/v1101: unsupported MM mode ' + mode)

def patch(rel, old, new):
    p = root / rel
    s = p.read_text()
    if s.count(old) != 1:
        raise SystemExit('v909 injection anchor mismatch: ' + rel +
                         ' count=' + str(s.count(old)))
    p.write_text(s.replace(old, new, 1))

# This pin is deliberately permanent. Only the original MM provider can
# reject the release. Restrict the hook to slot 2's stable u-area.
patch('mm/mm_pdp6.s',
      'mm_free:\n        move    5,1\n        move    6,2\n        move    7,3',
      '''mm_free:
        caie    3,01002               ; slot 2 u-area owner
        jrst    mm_free_original_v909
        caie    2,3                   ; MM_TYPE_KERNEL_DYNAMIC
        jrst    mm_free_original_v909
        skipn   daimos_test_target_v909
        movem   1,daimos_test_target_v909
        move    4,daimos_test_target_v909
        came    4,1
        jrst    daimos_test_target_bad_v909
        aos     daimos_test_calls_v909
        move    4,daimos_test_calls_v909
        caie    4,1
        jrst    daimos_test_free_normal_v909
        pushj   17,mm_pin             ; real physical MM pin
        jumpe   1,daimos_test_pin_ok_v909
        aos     daimos_test_errors_v909
        jrst    daimos_test_free_normal_v909
daimos_test_pin_ok_v909:
        aos     daimos_test_pins_v909
        jrst    daimos_test_free_normal_v909
daimos_test_target_bad_v909:
        aos     daimos_test_errors_v909
daimos_test_free_normal_v909:
        move    1,daimos_test_target_v909
        movei   2,3
        movei   3,01002
mm_free_original_v909:
        move    5,1
        move    6,2
        move    7,3''')
patch('mm/mm_pdp6.s',
      'mm_free_busy:\n        movni   1,5',
      '''mm_free_busy:
        move    4,daimos_test_target_v909
        camn    4,5
        aos     daimos_test_busy_v909
        movni   1,5''')
if mode == 'wrong-owner':
    # The original MM table keeps the allocated extent. In the isolated
    # kernel, corrupt only its exact owner *once* before the first free,
    # so every subsequent real mm_free returns MM_ERR_INVAL (-4).
    # mm_uarea_probe must independently report WRONG_OWNER (0402).
    patch('mm/mm_pdp6.s',
          '''        pushj   17,mm_pin             ; real physical MM pin
        jumpe   1,daimos_test_pin_ok_v909''',
          '''        pushj   17,mm_find_base
        caml    1,mm_extent_count
        jrst    daimos_test_target_bad_v909
        lsh     1,1
        movei   4,01003               ; deliberately wrong owner
        hrrm    4,mm_extents+1(1)
        setz    1,
        jumpe   1,daimos_test_pin_ok_v909''')
    patch('mm/mm_pdp6.s',
          'aos     daimos_test_pins_v909',
          'aos     daimos_test_poison_v1101')
    patch('mm/mm_pdp6.s',
          'mm_free_inval:\n        movni   1,4',
          '''mm_free_inval:
        move    4,daimos_test_target_v909
        camn    4,5
        aos     daimos_test_invalid_v1101
        movni   1,4''')
p=root/'mm/mm_pdp6.s'
p.write_text(p.read_text()+'''
        .globl mm_pin
        .bss
        .globl daimos_test_target_v909
daimos_test_target_v909: .block 1
        .globl daimos_test_calls_v909
daimos_test_calls_v909: .block 1
        .globl daimos_test_pins_v909
daimos_test_pins_v909: .block 1
        .globl daimos_test_busy_v909
daimos_test_busy_v909: .block 1
        .globl daimos_test_errors_v909
daimos_test_errors_v909: .block 1
''')
if mode == 'wrong-owner':
    p.write_text(p.read_text()+'''
        .bss
        .globl daimos_test_poison_v1101
daimos_test_poison_v1101: .block 1
        .globl daimos_test_invalid_v1101
daimos_test_invalid_v1101: .block 1
''')
patch('drivers/clk_io.s',
      'clk_pi_user_fault_exit:\n        movei 1,SYS_WAIT_EVENT_TERM',
      '''clk_pi_user_fault_exit:
        aos     daimos_test_faults_v909
        movei 1,SYS_WAIT_EVENT_TERM''')
# Instrument actual maintenance work, not clock interrupts.
patch('proc/proc_pdp6.s',
      'proc_finish_service_v881:\n        push    17,10',
      '''proc_finish_service_v881:
        aos     daimos_test_reaper_v909
        push    17,10''')
patch('proc/proc_pdp6.s',
      'proc_exit_current:\n        move    3,1',
      '''proc_exit_current:
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_exit_other_v909
        halt                           ; only after PID 1's validation
        jrst    .-1
daimos_test_exit_other_v909:
        move    3,1''')
p=root/'proc/proc_pdp6.s'
p.write_text(p.read_text()+'''
        .bss
        .globl daimos_test_reaper_v909
daimos_test_reaper_v909: .block 1
        .globl daimos_test_faults_v909
daimos_test_faults_v909: .block 1
''')
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
if [ "${DAIMOS_V1101_MM_MODE:-pin}" = wrong-owner ]; then
    expected_detail='-DDAIMOS_MM_EXPECT_VALUE=0402U'
else
    expected_detail=''
fi
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $inc $expected_detail -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-fatal-mm-persistent-v909.c" -o "$work/user/init.s"
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
        echo "v909: isolated kernel/image build failed: $work" >&2
        exit 1
    }
map="$build/kcore.map"
for name in target calls pins busy errors reaper faults; do
    sym="daimos_test_${name}_v909"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v909: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
if [ "${DAIMOS_V1101_MM_MODE:-pin}" = wrong-owner ]; then
    for name in poison invalid; do
        sym="daimos_test_${name}_v1101"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1101: missing $sym" >&2; exit 1; }
        printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 85s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/simh.out" >&2
    echo "v909: SIMH failed ($rc): $work" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" "${DAIMOS_V1101_MM_MODE:-pin}" <<'PY'
from pathlib import Path
import re
import sys
out=Path(sys.argv[2]).read_text(errors='replace')
mode=sys.argv[3]
seen={}
for line in Path(sys.argv[1]).read_text().splitlines():
    name,addr=line.split()
    values=re.findall(r'(?im)^\s*0*'+re.escape(addr.lstrip('0'))+
                      r'\s*:\s*([0-7]+)\b',out)
    if not values:
        raise SystemExit('v909: missing counter '+name+'\n'+out[-1600:])
    seen[name]=int(values[-1],8)
print('v909/v1101 physical-MM permanent-refusal counters:', seen)
if seen['faults']!=1 or seen['errors']!=0 or not seen['target'] or \
   not (5<=seen['calls']<=12) or not (4<=seen['reaper']<=12):
    raise SystemExit('v909: lost MM owner, unbounded reaper, or missing fault')
if mode == 'pin':
    if seen['pins'] != 1 or seen['busy'] != seen['calls']:
        raise SystemExit('v909: physical pin/busy counts incorrect')
else:
    if seen['pins'] != 0 or seen['busy'] != 0 or \
       seen['poison'] != 1 or seen['invalid'] != seen['calls']:
        raise SystemExit('v1101: wrong-owner invalid MM counts: '+str(seen))
if '<' not in out or 'F' not in out or 'P' not in out or \
   re.search(r'<FS{3,}P',out) is None or 'HALT' not in out or '!' in out:
    raise SystemExit('v909: spinner/diagnostic/guest failed\n'+out[-1300:])
if mode == 'pin':
    print('v909: permanent actual-MM pin, capped idle-reaper, retained owner, '
          'unreaped WAIT, runnable bystander PASS')
else:
    print('v1101: permanent MM wrong owner (-4), retained failed owner, '
          'capped idle-reaper, unreaped WAIT, runnable bystander PASS')
PY
