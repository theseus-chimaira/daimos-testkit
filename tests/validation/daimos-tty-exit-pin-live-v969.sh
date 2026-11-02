#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-tty-exit-pin-live-v969
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

cleanup()
{
        if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$user" "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-tty-exit-pin-live-v969.py" \
    "$work/source/system/kernel/proc/proc_pdp6.s"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/ipc" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-tty-session-state-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$user/init.map" || {
        echo "$tag: INIT is not linked at logical 020" >&2
        exit 1
}

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" \
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$user/init.dxr" SIMH_DPY_MODE=HEADLESS >/dev/null
boot="$build/system/boot/pdp6"
# The full-system session test needs no SDL window devices.
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' "$boot/boot.ini"
for name in attempt matched entry armed retained retried error_word; do
    sym="daimos_test_pin_${name}_v969"
    addr=$(awk -v sym="$sym" '$1 == sym {print $2}' "$boot/kcore.map")
    test -n "$addr" || { echo "$tag: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
sed -i '/^exit$/d' "$boot/boot.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot/boot.ini"
done < "$work/addresses"
printf 'exit\n' >> "$boot/boot.ini"
out="$work/simh.out"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 45s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" boot.ini
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi
text=$(tr -d '\r\n' <"$out")
case "$text" in
*'<'*) text=${text#*<} ;;
*)
        cat "$out" >&2
        echo "$tag: test sentinel missing" >&2
        exit 1
        ;;
esac
case "$text" in
*'!'*)
        cat "$out" >&2
        echo "$tag: target process reported failure" >&2
        exit 1
        ;;
esac
case "$text" in
*'H'*'HALT'*) ;;
*)
        cat "$out" >&2
        echo "$tag: completion/HALT missing" >&2
        exit 1
        ;;
esac

python3 - "$work/addresses" "$out" <<'PY'
from pathlib import Path
import re
import sys

out = Path(sys.argv[2]).read_text(errors='replace')
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr = line.split()
    m = re.findall(r'(?m)^\s*0*' + re.escape(addr.lstrip('0')) +
                   r'\s*:\s*([0-7]+)', out)
    print('v969 witness', name, m[-1] if m else 'MISSING')
    if not m or (name not in ('matched', 'entry', 'armed') and int(m[-1], 8) !=
                 (0 if name == 'error_word' else 1)) or \
            (name == 'matched' and int(m[-1], 8) < 1):
        raise SystemExit('v969: unexpected ' + name + ': ' + repr(m))
print('v969: booted final-session pinned TTY retains, unpins, retries PASS')
PY
