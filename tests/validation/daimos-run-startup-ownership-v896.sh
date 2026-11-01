#!/bin/sh
# Full PDP-6 guest: rejected startup must release its exact MM u-area.
# Fault injection exists only in a copied kernel; DAIMOS stays unmodified.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
case "${DAIMOS_V896_NEGATIVE:-0}" in
    0|1) ;;
    *) echo 'v896: DAIMOS_V896_NEGATIVE must be 0 or 1' >&2; exit 2 ;;
esac
work=$(mktemp -d "$TMPDIR/daimos-run-startup-ownership-v896.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"

python3 - "$work/source/system/kernel/proc/proc_run.s" \
    "${DAIMOS_V896_NEGATIVE:-0}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
negative = sys.argv[2] == '1'
source = path.read_text()
def patch(old, new):
    global source
    if source.count(old) != 1:
        raise SystemExit('v896: invalid isolated hook: ' + repr(old))
    source = source.replace(old, new)

# Record the exact allocated u-area base and check that an unsuccessful
# startup has freed its MM descriptor, not merely cleared the process slot.
patch('        move    1,014\n        movei   2,PROC_UAREA_WORDS\n        pushj   17,fs_zero_words',
      """        move    1,014
        movei   2,PROC_UAREA_WORDS
        pushj   17,fs_zero_words
        skipn   daimos_test_uarea_base_v896
        movem   014,daimos_test_uarea_base_v896""")
patch('        move    1,012\n        pushj   17,proc_slot_discard\nproc_run_bad:',
      """        move    1,012
        pushj   17,proc_slot_discard
        aos     daimos_test_discards_v896
        move    1,daimos_test_uarea_base_v896
        move    2,012                  ; unpublished child's MM owner
        pushj   17,mm_uarea_probe_v887
        caie    1,0400                 ; exact physical extent is missing
        aos     daimos_test_leaks_v896 ; unexpected surviving allocation
proc_run_bad:""")
source += """
        .globl mm_uarea_probe_v887
        .bss
        .globl daimos_test_uarea_base_v896
daimos_test_uarea_base_v896: .block 1
        .globl daimos_test_discards_v896
daimos_test_discards_v896: .block 1
        .globl daimos_test_leaks_v896
daimos_test_leaks_v896: .block 1
"""

# Reject only the first child RUN startup, not the initial system INIT
# startup or EXEC's separate invocation of vm_space_startup. The valid
# second RUN follows the original helper without changes.
patch('        pushj   17,vm_space_startup\n        jumpn   1,proc_run_startup_failed',
      """        skipn   daimos_test_startup_rejected_v896
        jrst    daimos_test_startup_fail_v896
        pushj   17,vm_space_startup
        jumpn   1,proc_run_startup_failed
        jrst    daimos_test_startup_ok_v896
daimos_test_startup_fail_v896:
        setom   daimos_test_startup_rejected_v896
        seto    1,
        jrst    proc_run_startup_failed
daimos_test_startup_ok_v896:""")
source += """
        .bss
        .globl daimos_test_startup_rejected_v896
daimos_test_startup_rejected_v896: .block 1
"""
# Negative control restores the precise v895 ownership ordering in the
# isolated source. The source and tests in the real DAIMOS tree stay intact.
if negative:
    published = """        ; Publish MM ownership before startup can fail.  Discard uses the
        ; stable descriptor to release this u-area on *every* later error;
        ; attaching it only after startup stranded its allocation if that
        ; helper rejected construction.  The freshly zeroed u-area has no
        ; FILE references and remains unpublished in SIDL.
        hrlm    014,(013)
        movei   4,PROC_F_UAREA_RH
        iorm    4,(013)

"""
    old_location = """        movem   4,021(014)

        ; Inherit SESSION/DOMAIN"""
    if source.count(published) != 1 or source.count(old_location) != 1:
        raise SystemExit('v896: negative control requires v896 ordering')
    source = source.replace(published, '')
    source = source.replace(old_location, """        movem   4,021(014)

        hrlm    014,(013)
        movei   4,PROC_F_UAREA_RH
        iorm    4,(013)

        ; Inherit SESSION/DOMAIN""")
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
    -S "$self/daimos-run-startup-ownership-v896.c" -o "$work/user/init.s"
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
        echo 'v896: isolated build failed' >&2
        exit 1
    }

for name in uarea_base discards leaks startup_rejected; do
    sym="daimos_test_${name}_v896"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v896: missing $sym" >&2; exit 1; }
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
    echo "v896: PDP-6 simulator exited $rc" >&2
    exit 1
fi

python3 - "$work/addresses" "$work/simh.out" \
    "${DAIMOS_V896_NEGATIVE:-0}" <<'PY'
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
        raise SystemExit('v896: missing sample ' + name + '\n' + output[-1500:])
    seen[name] = int(values[-1], 8)
negative = sys.argv[3] == '1'
expected = dict(discards=1, leaks=1 if negative else 0,
                startup_rejected=(1 << 36)-1)
for name, value in expected.items():
    if seen[name] != value:
        raise SystemExit('v896: ' + name + '=' + str(seen[name]) +
                         ' expected ' + str(value) + '\n' + output[-1800:])
if seen['uarea_base'] == 0 or 'HALT' not in output or '!' in output or \
        '<' not in output or 'R' not in output or 'B' not in output or \
        'P' not in output:
    raise SystemExit('v896: RUN/WAIT/recovery markers failed\n' +
                     output[-1800:])
print('v896: full PDP-6 ' +
      ('negative control detects retained MM u-area' if negative else
       'rejected RUN startup frees exact MM u-area') +
      '; second RUN and WAIT PASS:', seen)
PY
