#!/bin/sh
# K04 v1796: booted PDP-6 fatal FILE-close refusal, descriptor retention,
# and ordering of the private-stack HUP before MM finalization.
# All test instrumentation belongs to the disposable kernel copy.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
DAIMOS_REPO=${DAIMOS_REPO:-$HOME/git/DAIMOS}
export TMPDIR PDP10_PREFIX DAIMOS_REPO
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
work="$TMPDIR/daimos-k04-v1796-file-fatal"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
test ! -e "$work" || {
    echo "v1796 scratch already exists: $work" >&2
    exit 2
}
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-k04-file-fatal-fixture-v1796.py" \
    "$work/source/system/kernel"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -F -C -O "$work/user/crt0.dobj" \
    "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$work/user/syscall.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
incs=""
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-k04-file-fatal-v1796.c" \
    -o "$work/user/init.s"
"$das" -F -C -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"
echo 'v1796 native C89 compile, DAS, link PASS'

build="$work/build/system/boot/pdp6"
nice -n 15 "${MAKE:-make}" -C "$DAIMOS_REPO/system/boot/pdp6" \
    image BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" \
    SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -75 "$work/build.log" >&2
        exit 1
    }
echo 'v1796 full PDP-6 boot image PASS'
d6fsck -n 4 -d "$build/disk"

python3 - "$build" <<'PY'
from pathlib import Path
import sys

build = Path(sys.argv[1])
map_text = (build / 'kcore.map').read_text().splitlines()
labels = ('k04_sync_calls_v1796', 'k04_sync_refused_v1796',
          'k04_sync_delegated_v1796', 'k04_sync_mismatch_v1796',
          'k04_session_calls_v1796', 'k04_session_bad_v1796')
addresses = {}
for row in map_text:
    pair = row.split()
    if len(pair) == 2 and pair[0] in labels:
        if pair[0] in addresses:
            raise ValueError('duplicate witness symbol')
        addresses[pair[0]] = pair[1]
if set(addresses) != set(labels):
    raise ValueError('missing scratch witness symbols')
(build / 'k04-v1796-witnesses.txt').write_text(''.join(
    '%s %s\n' % (name, addr) for name, addr in addresses.items()))
p = build / 'boot.ini'
s = p.read_text()
s = s.replace('set wcnsls enabled\n', 'set wcnsls disabled\n')
s = s.replace('set ocnsls enabled\n', 'set ocnsls disabled\n')
s = s.replace('set dpy window\n', '; v1796 headless SDL-free guest\n')
if s.count('go 020\nexit\n') != 1:
    raise ValueError('unsafe SIMH boot control flow')
commands = ''.join('examine %s\n' % addresses[name] for name in labels)
s = s.replace('go 020\nexit\n', 'go 020\n' + commands + 'exit\n')
p.write_text(s)
print('v1796 post-HALT witness map:', addresses)
PY

# No forced stop while writable media is attached. The guest either
# calls dsys_halt, or its own diagnostic HALT; any other outcome must
# be investigated on this disposable media before it is accepted.
echo 'v1796 launching isolated full-system PDP-6'
(cd "$build"; TERM=dumb nice -n 15 pdp6 boot.ini) \
    > "$work/simh.out" 2>&1
echo 'v1796 simulator exited; independent verification follows'
python3 "$self/daimos-k04-file-fatal-verify-v1796.py" \
    "$build/k04-v1796-witnesses.txt" "$work/simh.out" "$build/disk"
