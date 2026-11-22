#!/bin/sh
# Real PDP-6 session leader HUP with a separately refused member FILE.
# C89 guest, all kernel instrumentation confined to disposable copy.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
DAIMOS_REPO=${DAIMOS_REPO:-$HOME/git/DAIMOS}
export TMPDIR PDP10_PREFIX DAIMOS_REPO
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work="$TMPDIR/daimos-k04-v1798-multimember-hup"
test ! -e "$work" || {
    echo "v1798 scratch already exists: $work" >&2
    exit 2
}
mkdir -p "$work/source/system" "$work/user" \
    "$work/prior-v1796/kernel/fs" "$work/prior-v1796/kernel/proc"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
cp "$DAIMOS_REPO/system/kernel/fs/vfs.s" \
    "$work/prior-v1796/kernel/fs/vfs.s"
cp "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$work/prior-v1796/kernel/proc/proc_pdp6.s"
python3 "$self/daimos-k04-file-fatal-fixture-v1796.py" \
    "$work/prior-v1796/kernel"
python3 "$self/daimos-k04-multimember-hup-fixture-v1798.py" \
    "$work/source/system/kernel" \
    "$work/prior-v1796/kernel/fs/vfs.s"

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
    -S "$self/daimos-k04-multimember-hup-v1798.c" \
    -o "$work/user/init.s"
"$das" -F -C -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"
echo 'v1798 guest C89 native compile, DAS, link PASS'

build="$work/build/system/boot/pdp6"
nice -n 15 "${MAKE:-make}" -C "$DAIMOS_REPO/system/boot/pdp6" \
    image BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" \
    SIMH_DPY_MODE=HEADLESS > "$work/build.log" 2>&1 || {
        tail -80 "$work/build.log" >&2
        exit 1
    }
echo 'v1798 full scratch 256K image build PASS'
d6fsck -n 4 -d "$build/disk"
python3 - "$build" <<'PY'
from pathlib import Path
import sys

build = Path(sys.argv[1])
symbols = (
    'k04_sync_calls_v1798',
    'k04_sync_refused_v1798',
    'k04_sync_delegated_v1798',
    'k04_sync_mismatch_v1798',
    'k04_hup_calls_v1798',
    'k04_hup_fails_v1798',
    'k04_hup_success_v1798',
    'k04_hup_bad_v1798',
    'k04_hup_targets_v1798',
    'k04_hup_protected_v1798',
)
found = {}
for line in (build / 'kcore.map').read_text().splitlines():
    fields = line.split()
    if len(fields) == 2 and fields[0] in symbols:
        if fields[0] in found:
            raise ValueError('ambiguous v1798 symbol')
        found[fields[0]] = fields[1]
if set(found) != set(symbols):
    raise ValueError('missing HUP or FILE physical BSS witness')
(build / 'k04-v1798-witnesses.txt').write_text(''.join(
    '%s %s\n' % (name, found[name]) for name in symbols))
boot = build / 'boot.ini'
s = boot.read_text()
if s.count('go 020\nexit\n') != 1:
    raise ValueError('SIMH script must HALT before physical examine')
s = s.replace('set wcnsls enabled\n', 'set wcnsls disabled\n')
s = s.replace('set ocnsls enabled\n', 'set ocnsls disabled\n')
s = s.replace('set dpy window\n', '; v1798 headless guest\n')
examine = ''.join('examine %s\n' % found[name] for name in symbols)
s = s.replace('go 020\nexit\n', 'go 020\n' + examine + 'exit\n')
boot.write_text(s)
print('v1798 physical HUP/FILE witnesses:', found)
PY

echo 'v1798 launching real PDP-6; guest must HALT normally'
(cd "$build"; TERM=dumb nice -n 15 pdp6 boot.ini) \
    > "$work/simh.out" 2>&1
echo 'v1798 guest stopped; inspecting real source-linked witnesses'
python3 "$self/daimos-k04-multimember-hup-verify-v1798.py" \
    "$build/k04-v1798-witnesses.txt" "$work/simh.out" "$build/disk"
