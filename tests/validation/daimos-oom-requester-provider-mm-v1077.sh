#!/bin/sh
# Disposable PDP-6 physical-OOM teardown: real D6FS SYNC and MM_BUSY
# refusals with requester-only termination. Production is unchanged.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
enable=1
work=$(mktemp -d "$TMPDIR/daimos-oom-requester-provider-mm-v1077.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1077 work: $work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" "$enable" <<'PY'
from pathlib import Path
import os
import sys
p = Path(sys.argv[1])
s = p.read_text()
off = '.equ    PROC_OOM_BRK_ENABLED_V1000,0'
on = '.equ    PROC_OOM_BRK_ENABLED_V1000,1'
expected = os.environ.get('V1283_PRODUCTION_OOM_DEFAULT', '0')
assert expected in ('0', '1'), 'invalid production OOM expectation'
assert s.count(off) + s.count(on) == 1, 'ambiguous production OOM policy'
original = off if expected == '0' else on
assert s.count(original) == 1, 'unexpected production OOM policy'
desired = off if sys.argv[2] == '0' else on
if original != desired:
    p.write_text(s.replace(original, desired, 1))
PY

# All injection is confined to the disposable kernel. The real D6FS
# provider, FILE close retry and MM finalizer remain in the call chain.
python3 - "$work/source/system/kernel" <<'PYFAULT'
from pathlib import Path
import sys
root = Path(sys.argv[1])
def patch(rel, old, new):
    p = root / rel
    src = p.read_text()
    if src.count(old) != 1:
        raise SystemExit('v1077: nonunique fault anchor ' + rel)
    p.write_text(src.replace(old, new, 1))

# Refuse two actual D6FS SYNC calls on the open /SYSTEM/INIT vnode.
patch('fs/d6fs_runtime.s',
      '''d6fs_provider_sync:
        jrst    kret_zero''',
      '''d6fs_provider_sync:
        aos     daimos_oom_sync_attempts_v1077
        move    4,daimos_oom_sync_attempts_v1077
        caig    4,2
        jrst    daimos_oom_sync_refuse_v1077
        jrst    kret_zero
daimos_oom_sync_refuse_v1077:
        seto    1,
        popj    17,''')
p = root / 'fs/d6fs_runtime.s'
p.write_text(p.read_text() + '''
        .bss
daimos_oom_sync_attempts_v1077: .block 1
''')

# Measure the production FILE/VFS boundary only for the OOM child
# and the D6FS provider, rather than counting unrelated device closes.
patch('fs/file_runtime.s',
      '''file_close_vfs:
        pushj   17,vfs_sync
file_close_finish:''',
      '''file_close_vfs:
        push    17,2
        push    17,3
        move    2,proc_current_slot
        caie    2,3
        jrst    daimos_oom_sync_other_v1077
        ldb     3,[POINT 6,1,5]
        caie    3,6
        jrst    daimos_oom_sync_other_v1077
        aos     daimos_oom_close_calls_v1077
daimos_oom_sync_other_v1077:
        pop     17,3
        pop     17,2
        pushj   17,vfs_sync
        jumpe   1,file_close_finish
        push    17,2
        move    2,proc_current_slot
        caie    2,3
        jrst    daimos_oom_close_other_v1077
        aos     daimos_oom_close_refusals_v1077
daimos_oom_close_other_v1077:
        pop     17,2
file_close_finish:''')
p = root / 'fs/file_runtime.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_oom_close_calls_v1077
daimos_oom_close_calls_v1077: .block 1
        .globl daimos_oom_close_refusals_v1077
daimos_oom_close_refusals_v1077: .block 1
''')

# First u-area release returns MM_BUSY. Idle-stack retry must preserve
# the dying process's ownership and complete it on the second call.
patch('mm/mm_pdp6.s',
      '''mm_free:
        move    5,1''',
      '''mm_free:
        caie    2,3                   ; MM_TYPE_KERNEL_DYNAMIC
        jrst    daimos_oom_mm_other_v1077
        caie    3,01003               ; requester slot 3 u-area
        jrst    daimos_oom_mm_other_v1077
        aos     daimos_oom_mm_calls_v1077
        move    0,daimos_oom_mm_calls_v1077
        caie    0,1
        jrst    daimos_oom_mm_other_v1077
        aos     daimos_oom_mm_refusals_v1077
        movni   1,5
        popj    17,
daimos_oom_mm_other_v1077:
        move    5,1''')
p = root / 'mm/mm_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_oom_mm_calls_v1077
daimos_oom_mm_calls_v1077: .block 1
        .globl daimos_oom_mm_refusals_v1077
daimos_oom_mm_refusals_v1077: .block 1
''')
PYFAULT

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -F -C -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=
for sub in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$sub"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os -DV1077_TEST_OOM_ENABLED="$enable" \
    $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-oom-requester-provider-mm-v1077.c" -o "$work/user/init.s"
"$das" -F -C -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"

build="$work/build/system/boot/pdp6"
port=$((30000 + ($$ % 10000)))
printf 'v1077: building disposable PDP-6 physical-OOM guest (enabled=%s)\n' "$enable"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    KERNEL_DIR="$work/source/system/kernel" PROC_BOOT_USERS=1 \
    BOOT_PROFILE=full BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 \
    SIMH_DCS0_PORT="$port" SIMH_GE0_PORT="$((port + 10000))" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -90 "$work/build.log" >&2
        exit 1
    }
sed -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' "$build/boot.ini" \
    > "$build/boot.v1077.tmp"
mv "$build/boot.v1077.tmp" "$build/boot.ini"

# Inspect only the KCORE-owned witnesses after the user's controlled
# HALT; D6FS lives in a separate MRES and is observed through VFS.
: > "$work/addresses"
for name in close_calls close_refusals mm_calls mm_refusals; do
    sym="daimos_oom_${name}_v1077"
    addr=$(awk -v s="$sym" '$1 == s {print $2; exit}' "$build/kcore.map")
    [ -n "$addr" ] || { echo "v1077: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
sed '/^exit$/d' "$build/boot.ini" > "$build/boot.v1077-examine.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$build/boot.v1077-examine.ini"
done < "$work/addresses"
printf 'exit\n' >> "$build/boot.v1077-examine.ini"

printf 'v1077: booting patched disposable guest; production unchanged\n'
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s 90s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.v1077-examine.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -65 "$work/simh.out" >&2
    echo "v1077: SIMH exit $rc" >&2
    exit 1
fi
python3 - "$work/simh.out" "$work/addresses" <<'PYCHECK'
from pathlib import Path
import re
import sys
out = Path(sys.argv[1]).read_text(errors='replace')
compact = out.replace('\r', '').replace('\n', '')
if '<KWP' not in compact or 'HALT' not in compact or '!' in compact:
    raise SystemExit('v1077: guest OOM/witness/accounting failure\n' +
                     out[-2500:])
seen = {}
for item in Path(sys.argv[2]).read_text().splitlines():
    name, addr = item.split()
    matches = re.findall(r'(?im)^\s*0*' + re.escape(addr.lstrip('0')) +
                         r'\s*:\s*([0-7]+)\b', out)
    if not matches:
        raise SystemExit('v1077: no counter ' + name + ' at ' + addr +
                         '\n' + out[-2500:])
    seen[name] = int(matches[-1], 8)
expected = dict(close_calls=3, close_refusals=2,
                mm_calls=2, mm_refusals=1)
if seen != expected:
    raise SystemExit('v1077: FILE/MM retry mismatch: ' + str(seen) +
                     '\n' + out[-2500:])
print('v1077: D6FS SYNC 2 refusals; MM_BUSY 1 refusal; OOM/witness recovery PASS:',seen)
PYCHECK
